@_exported import ClerkSnapshots
import ClerkWatchCompanion
import CryptoKit
import Foundation

@MainActor
public final class ClerkJSHost: ClerkJSBridge {
  private let publishableKey: String
  package nonisolated let runtime: ClerkJSRuntime
  private var loadTask: Task<Void, Error>?
  private var stateError: (any Error)?
  public var onStateChange: (@MainActor (ClerkJSState) async throws -> Void)?
  private var stateTask: Task<Void, Error>?
  private var disposed = false
  public private(set) var state: ClerkJSState?

  public init(
    publishableKey: String,
    tokenCache: ClerkJSTokenCache = .memory(),
    resourceCache: ClerkJSResourceCache? = nil,
    secureStorage: ClerkJSSecureStorage = .memory(),
    biometricCredential: ClerkJSNativeCapability? = nil,
    oauthRedirectURL: URL = ClerkJSRuntime.defaultOAuthRedirectURL,
    proxyURL: URL? = nil,
    appAttestKeyIdStore: ClerkJSAppAttestKeyIdStore = .memory(),
    sessionConfiguration: URLSessionConfiguration? = nil,
    httpMiddleware: ClerkJSHTTPMiddleware = .init()
  ) {
    self.publishableKey = publishableKey
    runtime = ClerkJSRuntime(
      tokenCache: tokenCache,
      resourceCache: resourceCache,
      secureStorage: secureStorage,
      biometricCredential: biometricCredential,
      oauthRedirectURL: oauthRedirectURL,
      proxyURL: proxyURL,
      appAttestKeyIdStore: appAttestKeyIdStore,
      sessionConfiguration: sessionConfiguration,
      httpMiddleware: httpMiddleware
    )
    runtime.setStateCommitHandler { [weak self] data in
      guard let self else { throw ClerkJSCoreError.disposed }
      try await enqueueState(data).value
    }
    runtime.observeState { [weak self] data in
      Task { @MainActor [weak self] in
        guard let self else { return }
        do { try await enqueueState(data).value } catch { stateError = error }
      }
    }
  }

  public static func persistent(publishableKey: String) -> ClerkJSHost {
    let service = "com.clerk.jscore.\(storageNamespace(for: publishableKey))"
    return ClerkJSHost(
      publishableKey: publishableKey,
      tokenCache: .keychain(service: service, account: "client-jwt"),
      resourceCache: .keychain(
        service: service,
        clientAccount: "client-snapshot",
        environmentAccount: "environment-snapshot"
      ),
      secureStorage: .keychain(service: service),
      appAttestKeyIdStore: .keychain(service: service)
    )
  }

  nonisolated static func storageNamespace(for publishableKey: String) -> String {
    SHA256.hash(data: Data(publishableKey.utf8))
      .prefix(8)
      .map { String(format: "%02x", $0) }
      .joined()
  }

  public var client: Client? {
    state?.client
  }

  public var environment: ClerkEnvironment? {
    state?.environment
  }

  package static func snapshotEnvironmentJSON() throws -> Data {
    guard let url = Bundle.module.url(forResource: "environment-snapshot", withExtension: "json") else {
      throw ClerkJSCoreError.missingBundle
    }
    return try Data(contentsOf: url)
  }

  package static func snapshotSignedInClient() throws -> Data {
    guard let url = Bundle.module.url(forResource: "signed-in-client", withExtension: "json") else {
      throw ClerkJSCoreError.missingBundle
    }
    return try Data(contentsOf: url)
  }

  public var nativeSettings: NativeSettings {
    environment?.authConfig.nativeSettings ?? .default
  }

  public var watchCompanion: WatchCompanion {
    WatchCompanion(client: client, environment: environment)
  }

  package var lastClientJSON: Data? {
    runtime.lastFAPIClientJSON
  }

  package var lastEnvironmentJSON: Data? {
    runtime.lastFAPIEnvironmentJSON
  }

  package var lastClientToken: String? {
    runtime.lastClientToken
  }

  public func load() async throws {
    if let loadTask {
      try await loadTask.value
    } else {
      let task = Task { try await self.runtime.load(publishableKey: self.publishableKey) }
      loadTask = task
      do { try await task.value } catch {
        loadTask = nil
        throw error
      }
    }
    try await consumeState()
  }

  public func dispose() async {
    disposed = true
    onStateChange = nil
    loadTask?.cancel()
    await runtime.dispose()
    _ = await stateTask?.result
    loadTask = nil
  }

  public func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue {
    do {
      let payload = try await runtime.invoke(invocation)
      try await consumeState()
      return payload
    } catch {
      try await consumeState()
      throw error
    }
  }

  private func consumeState() async throws {
    if let data = runtime.lastStateJSON { try await enqueueState(data).value }
    if let stateError { throw stateError }
  }

  private func enqueueState(_ data: Data) -> Task<Void, Error> {
    let previous = stateTask
    let task = Task {
      _ = await previous?.result
      try await self.acceptState(data)
    }
    stateTask = task
    return task
  }

  private func acceptState(_ data: Data) async throws {
    guard !disposed else { throw ClerkJSCoreError.disposed }
    let next = try JSONDecoder().decode(ClerkJSState.self, from: data)
    guard next.protocolVersion == 1, next.generation == runtime.generation else {
      throw ClerkJSCoreError.invalidArgument("state protocol or generation")
    }
    guard next.revision > (state?.revision ?? 0) else { return }
    try await onStateChange?(next)
    guard !disposed else { throw ClerkJSCoreError.disposed }
    state = next
    stateError = nil
  }

  public func startAppleAuthentication() async throws -> AppleIdentityToken {
    try await runtime.startAppleAuthentication()
  }

  public func biometricPresence(_ params: BiometricPromptParams = .init()) async throws -> BiometricPresence {
    try await runtime.biometricPresence(params)
  }

  public func promptBiometrics(_ params: BiometricPromptParams = .init()) async throws -> BiometricAuthentication {
    try await runtime.promptBiometrics(params)
  }

  public func prepareDeviceAttestation(_ params: DeviceAttestParams) async throws -> DeviceAttestationProof {
    try await runtime.prepareDeviceAttestation(params)
  }

  public func prepareDeviceAssertion(_ params: DeviceAttestParams) async throws -> DeviceAssertionProof {
    try await runtime.prepareDeviceAssertion(params)
  }
}
