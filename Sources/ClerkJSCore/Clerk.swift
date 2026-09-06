@_exported import ClerkSnapshots
import ClerkWatchCompanion
import CryptoKit
import Foundation

private typealias FAPIClient = Client
private typealias FAPISignIn = SignIn

private struct EmptyArgs: Encodable {}

package enum ClerkJSPath {
  private static let instance = "__clerkInstance"

  static func clerk(_ method: ClerkJSMethod) -> String {
    "\(instance).\(method.rawValue)"
  }

  static func signIn(_ method: SignInJSMethod) -> String {
    "\(instance).client.signIn.\(method.rawValue)"
  }

  static func session(_ method: SessionJSMethod) -> String {
    "\(instance).session.\(method.rawValue)"
  }
}

@MainActor
@Observable
public final class Clerk {
  @ObservationIgnored
  private let publishableKey: String
  @ObservationIgnored
  package nonisolated let runtime: ClerkJSRuntime
  private var fapiClient: FAPIClient?
  private var fapiEnvironment: Environment?
  private var fapiNativeSettings = NativeSettings.default

  public init(
    publishableKey: String,
    tokenCache: ClerkJSTokenCache = .memory(),
    resourceCache: ClerkJSResourceCache? = nil,
    appAttestKeyIdStore: ClerkJSAppAttestKeyIdStore = .memory()
  ) {
    self.publishableKey = publishableKey
    runtime = ClerkJSRuntime(
      tokenCache: tokenCache,
      resourceCache: resourceCache,
      appAttestKeyIdStore: appAttestKeyIdStore
    )
  }

  public static func persistent(publishableKey: String) -> Clerk {
    let service = "com.clerk.jscore.\(storageNamespace(for: publishableKey))"
    return Clerk(
      publishableKey: publishableKey,
      tokenCache: .keychain(service: service, account: "client-jwt"),
      resourceCache: .keychain(
        service: service,
        clientAccount: "client-snapshot",
        environmentAccount: "environment-snapshot"
      ),
      appAttestKeyIdStore: .keychain(service: service)
    )
  }

  nonisolated static func storageNamespace(for publishableKey: String) -> String {
    SHA256.hash(data: Data(publishableKey.utf8))
      .prefix(8)
      .map { String(format: "%02x", $0) }
      .joined()
  }

  public var client: Client {
    Client(clerk: self)
  }

  public var environment: Environment? {
    fapiEnvironment
  }

  public var shouldShowDevelopmentModeWarning: Bool {
    guard let displayConfig = environment?.displayConfig else { return false }
    return displayConfig.showDevmodeWarning && displayConfig.instanceEnvironmentType != "production"
  }

  public var shouldShowSecuredByClerkFooter: Bool {
    shouldShowDevelopmentModeWarning || environment?.displayConfig.branded == true
  }

  package func publishEnvironment(_ environment: Environment) {
    fapiEnvironment = environment
  }

  package static func snapshotEnvironment() throws -> Environment {
    guard let url = Bundle.module.url(forResource: "environment-snapshot", withExtension: "json") else {
      throw ClerkJSCoreError.missingBundle
    }
    return try JSONDecoder().decode(Environment.self, from: Data(contentsOf: url))
  }

  public var nativeSettings: NativeSettings {
    fapiNativeSettings
  }

  public var watchCompanion: WatchCompanion {
    WatchCompanion(client: fapiClient, environment: fapiEnvironment)
  }

  public var session: ActiveSession {
    ActiveSession(clerk: self)
  }

  public func load() async throws {
    try await runtime.load(publishableKey: publishableKey)
    try publishLastClient()
    publishLastEnvironment()
  }

  public func setActive(_ params: SetActiveParams) async throws {
    _ = try await runtime.call(methodPath: ClerkJSPath.clerk(.setActive), args: params)
    try publishLastClient()
    publishLastEnvironment()
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

  public struct SetActiveParams: Encodable, Sendable {
    public var session: String?

    public init(session: String?) {
      self.session = session
    }
  }

  @MainActor
  public struct Client {
    unowned let clerk: Clerk

    public var id: String {
      clerk.fapiClient?.id ?? ""
    }

    public var sessions: [Session] {
      clerk.fapiClient?.sessions ?? []
    }

    public var lastActiveSessionId: String? {
      clerk.fapiClient?.lastActiveSessionId
    }

    public var signUp: SignUp? {
      clerk.fapiClient?.signUp
    }

    public var signIn: SignIn {
      SignIn(clerk: clerk)
    }
  }

  @MainActor
  public struct SignIn {
    unowned let clerk: Clerk

    public var id: String? {
      model?.id
    }

    public var status: SignInStatus? {
      model?.status
    }

    public var identifier: String? {
      model?.identifier
    }

    public var createdSessionId: String? {
      model?.createdSessionId
    }

    public var supportedFirstFactors: [SignInFirstFactor] {
      model?.supportedFirstFactors ?? []
    }

    @discardableResult
    public func create(_ params: CreateParams) async throws -> SignIn {
      try await clerk.callAndPublish(ClerkJSPath.signIn(.create), params)
      return clerk.client.signIn
    }

    @discardableResult
    public func prepareFirstFactor(_ params: PrepareFirstFactorParams) async throws -> SignIn {
      try await clerk.callAndPublish(ClerkJSPath.signIn(.prepareFirstFactor), params)
      return clerk.client.signIn
    }

    @discardableResult
    public func attemptFirstFactor(_ params: AttemptFirstFactorParams) async throws -> SignIn {
      try await clerk.callAndPublish(ClerkJSPath.signIn(.attemptFirstFactor), params)
      return clerk.client.signIn
    }

    public struct CreateParams: Encodable, Sendable {
      public var identifier: String

      public init(identifier: String) {
        self.identifier = identifier
      }
    }

    public struct PrepareFirstFactorParams: Encodable, Sendable {
      public var strategy: Strategy
      public var emailAddressId: String?

      public init(strategy: Strategy, emailAddressId: String? = nil) {
        self.strategy = strategy
        self.emailAddressId = emailAddressId
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encodeIfPresent(emailAddressId, forKey: .emailAddressId)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case emailAddressId
      }
    }

    public struct AttemptFirstFactorParams: Encodable, Sendable {
      public var strategy: Strategy
      public var code: String

      public init(strategy: Strategy, code: String) {
        self.strategy = strategy
        self.code = code
      }
    }

    public enum Strategy: String, Encodable, Sendable {
      case emailCode = "email_code"
    }

    private var model: FAPISignIn? {
      clerk.fapiClient?.signIn
    }
  }

  @MainActor
  public struct ActiveSession {
    unowned let clerk: Clerk

    public func getToken() async throws -> String {
      let json = try await clerk.runtime.call(
        methodPath: ClerkJSPath.session(.getToken),
        args: EmptyArgs()
      )
      return try JSONDecoder().decode(String.self, from: Data(json.utf8))
    }
  }

  private func callAndPublish(_ methodPath: String, _ args: some Encodable & Sendable) async throws {
    do {
      _ = try await runtime.call(methodPath: methodPath, args: args)
    } catch {
      try? publishLastClient()
      publishLastEnvironment()
      throw error
    }
    try publishLastClient()
    publishLastEnvironment()
  }

  private func publishLastClient() throws {
    guard let data = runtime.lastFAPIClientJSON else {
      throw ClerkJSCoreError.invalidArgument("lastFAPIClientJSON")
    }
    fapiClient = try FAPIJSON.decodeClient(data)
  }

  private func publishLastEnvironment() {
    guard let data = runtime.lastFAPIEnvironmentJSON else {
      return
    }
    fapiEnvironment = try? JSONDecoder().decode(Environment.self, from: data)
    fapiNativeSettings = (try? FAPIJSON.decodeNativeSettings(fromEnvironmentJSON: data)) ?? .default
  }
}
