import Foundation

public struct ClerkJSTokenCache: Sendable {
  public var getToken: @Sendable () async -> String
  public var saveToken: @Sendable (String) async -> Void

  public init(
    getToken: @escaping @Sendable () async -> String,
    saveToken: @escaping @Sendable (String) async -> Void
  ) {
    self.getToken = getToken
    self.saveToken = saveToken
  }

  public static func memory() -> ClerkJSTokenCache {
    let box = MemoryTokenBox()
    return ClerkJSTokenCache(
      getToken: { await box.get() },
      saveToken: { await box.save($0) }
    )
  }
}

private actor MemoryTokenBox {
  var token = ""

  func get() -> String {
    token
  }

  func save(_ token: String) {
    self.token = token
  }
}

public final class ClerkJSRuntime: @unchecked Sendable {
  public static let sdkVersion = "1.5.3"
  public let generation = UUID().uuidString

  public static var defaultOAuthRedirectURL: URL {
    let scheme = Bundle.main.bundleIdentifier ?? "clerk"
    return URL(string: "\(scheme)://sso-callback")!
  }

  #if os(watchOS)
  public init(
    sdkVersion _: String = ClerkJSRuntime.sdkVersion,
    tokenCache _: ClerkJSTokenCache = .memory(),
    resourceCache _: ClerkJSResourceCache? = nil,
    secureStorage _: ClerkJSSecureStorage = .memory(),
    biometricCredential _: ClerkJSNativeCapability? = nil,
    oauthRedirectURL _: URL = ClerkJSRuntime.defaultOAuthRedirectURL,
    proxyURL _: URL? = nil,
    appAttestKeyIdStore _: ClerkJSAppAttestKeyIdStore = .memory(),
    sessionConfiguration _: URLSessionConfiguration? = nil,
    httpMiddleware _: ClerkJSHTTPMiddleware = .init()
  ) {}

  public var lastStateJSON: Data? {
    nil
  }

  public func observeState(_: (@Sendable (Data) -> Void)?) {}
  public func setStateCommitHandler(_: (@Sendable (Data) async throws -> Void)?) {}
  public func dispose() async {}

  public var lastFAPIClientJSON: Data? {
    nil
  }

  public var lastFAPIEnvironmentJSON: Data? {
    nil
  }

  public var lastClientToken: String? {
    nil
  }

  public func load(publishableKey _: String) async throws {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func evaluateJSON(_: String) async throws -> String {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func invoke(_: ClerkJSInvocation) async throws -> JSONValue {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func startAppleAuthentication() async throws -> AppleIdentityToken {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func biometricPresence(_: BiometricPromptParams = .init()) async throws -> BiometricPresence {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func promptBiometrics(_: BiometricPromptParams = .init()) async throws -> BiometricAuthentication {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func prepareDeviceAttestation(_: DeviceAttestParams) async throws -> DeviceAttestationProof {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func prepareDeviceAssertion(_: DeviceAttestParams) async throws -> DeviceAssertionProof {
    throw ClerkJSCoreError.unsupportedPlatform
  }
  #else
  private let runtime: JSRuntime
  private let sdkVersion: String
  private let resourceCache: ClerkJSResourceCache?
  private let oauthRedirectURL: URL
  private let proxyURL: URL?

  public init(
    sdkVersion: String = ClerkJSRuntime.sdkVersion,
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
    self.sdkVersion = sdkVersion
    self.resourceCache = resourceCache
    self.oauthRedirectURL = oauthRedirectURL
    self.proxyURL = proxyURL
    runtime = JSRuntime(tokenCache: tokenCache, sessionConfiguration: sessionConfiguration)
    runtime.host.httpMiddleware = httpMiddleware
    runtime.host.resourceCache = resourceCache
    runtime.host.secureStorage = secureStorage
    runtime.host.biometricCredential = biometricCredential
    runtime.host.oauth.redirectURL = oauthRedirectURL
    runtime.host.appAttest.keyIdStore = appAttestKeyIdStore
  }

  var oauthSession: ClerkJSOAuthSession {
    runtime.host.oauth
  }

  var appleCeremony: ClerkJSAppleCeremony {
    runtime.host.apple
  }

  var biometricCeremony: ClerkJSBiometricCeremony {
    runtime.host.biometrics
  }

  var appAttestCeremony: ClerkJSAppAttestCeremony {
    runtime.host.appAttest
  }

  public var lastFAPIClientJSON: Data? {
    runtime.lastClientJSON
  }

  public var lastFAPIEnvironmentJSON: Data? {
    runtime.lastEnvironmentJSON
  }

  public var lastClientToken: String? {
    runtime.lastClientToken
  }

  public var lastStateJSON: Data? {
    runtime.lastStateJSON
  }

  public func observeState(_ handler: (@Sendable (Data) -> Void)?) {
    runtime.observeState(handler)
  }

  public func setStateCommitHandler(_ handler: (@Sendable (Data) async throws -> Void)?) {
    runtime.setStateCommitHandler(handler)
  }

  public func dispose() async {
    await runtime.dispose()
  }

  public func load(publishableKey: String) async throws {
    let pk = try Self.jsonString(publishableKey)
    let version = try Self.jsonString(sdkVersion)
    let generation = try Self.jsonString(generation)
    let proxy = try Self.jsonString(proxyURL?.absoluteString ?? "")
    let allowedProtocol = try Self.jsonString(Self.oauthAllowedRedirectProtocol(from: oauthRedirectURL))
    let oauthTransport = Self.oauthTransportInstallSource(redirectURL: oauthRedirectURL)
    _ = try await runtime.evaluateJSON("""
      (async function() {
        if (!globalThis.__clerkEmbeddedCore) {
          globalThis.__clerkEmbeddedCore = ClerkEmbedded.createEmbeddedClerk({
            protocolVersion: 1,
            generation: \(generation),
            publishableKey: \(pk),
            sdkVersion: \(version),
            options: {
              proxyUrl: \(proxy) || undefined,
              allowedRedirectProtocols: [\(allowedProtocol)],
              __internal_oauthTransport: \(oauthTransport)
            }
          }, {
            storage: function(request) { return __clerkNativeStorage(JSON.stringify(request)); },
            biometricCredential: function(request) { return __clerkNativeBiometricCredential(JSON.stringify(request)); },
            getToken: __clerkNativeGetToken,
            saveToken: __clerkNativeSaveToken,
            getCachedResources: __clerkNativeGetCachedResources,
            saveCachedResources: function(value) { return __clerkNativeSaveCachedResources(JSON.stringify(value)); },
            commitState: function(state) { return __clerkNativeCommitState(JSON.stringify(state)); },
            publish: function(state) { __clerkNativePublishState(JSON.stringify(state)); }
          });
          var clerk = globalThis.__clerkEmbeddedCore.clerk;
          globalThis.__clerkInstance = clerk;
          \(Self.passkeyHookInstallSource)
          \(Self.appleHookInstallSource)
          \(Self.biometricHookInstallSource)
          \(Self.appAttestHookInstallSource)
        }
        await globalThis.__clerkEmbeddedCore.load();
        return true;
      })()
      """)
  }

  public func evaluateJSON(_ js: String) async throws -> String {
    try await runtime.evaluateJSON(js)
  }

  public func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue {
    let data = try JSONEncoder().encode(invocation)
    guard let json = String(data: data, encoding: .utf8) else {
      throw ClerkJSCoreError.invalidArgument("invocation")
    }
    do {
      let result = try await runtime.invokeJSON(receiver: "__clerkEmbeddedCore", method: "invoke", argumentsJSON: "[\(json)]")
      return try JSONDecoder().decode(JSONValue.self, from: Data(result.utf8))
    } catch let ClerkJSCoreError.javascript(message) {
      throw ClerkJSError.parse(message)
    }
  }

  static let passkeyHookInstallSource = "ClerkEmbedded.installPasskeyHooks(clerk, { createPublicCredentials: __clerkNativeCreatePublicCredentials, getPublicCredentials: __clerkNativeGetPublicCredentials });"

  static let appleHookInstallSource = "ClerkEmbedded.installAppleHooks(clerk, { startAppleAuthentication: __clerkNativeAppleSignIn });"

  static let biometricHookInstallSource = "ClerkEmbedded.installBiometricHooks(clerk, { biometricPresence: __clerkNativeBiometricPresence, promptBiometrics: __clerkNativePromptBiometrics });"

  static let appAttestHookInstallSource = "ClerkEmbedded.installAppAttestHooks(clerk, { prepareDeviceAttestation: __clerkNativePrepareDeviceAttestation, prepareDeviceAssertion: __clerkNativePrepareDeviceAssertion });"

  public func startAppleAuthentication() async throws -> AppleIdentityToken {
    switch await appleCeremony.start(payload: "{}") {
    case .success(let identity):
      return identity
    case .failure(let error):
      if error.code == ClerkJSAppleError.cancelled.code {
        throw ClerkJSCoreError.cancelled
      }
      if error.code == ClerkJSAppleError.invalidPayload.code {
        throw ClerkJSCoreError.invalidArgument("appleIdentity")
      }
      throw ClerkJSCoreError.javascript(error.message)
    }
  }

  public func biometricPresence(_ params: BiometricPromptParams = .init()) async throws -> BiometricPresence {
    switch await biometricCeremony.presence(payload: params.json) {
    case .success(let presence):
      return presence
    case .failure(let error):
      if error.code == ClerkJSBiometricError.invalidPayload.code {
        throw ClerkJSCoreError.invalidArgument("biometrics")
      }
      throw ClerkJSCoreError.javascript(error.message)
    }
  }

  public func promptBiometrics(_ params: BiometricPromptParams = .init()) async throws -> BiometricAuthentication {
    switch await biometricCeremony.prompt(payload: params.json) {
    case .success(let authentication):
      return authentication
    case .failure(let error):
      if error.code == ClerkJSBiometricError.cancelled.code {
        throw ClerkJSCoreError.cancelled
      }
      if error.code == ClerkJSBiometricError.invalidPayload.code {
        throw ClerkJSCoreError.invalidArgument("biometrics")
      }
      throw ClerkJSCoreError.javascript(error.message)
    }
  }

  public func prepareDeviceAttestation(_ params: DeviceAttestParams) async throws -> DeviceAttestationProof {
    try await mapAppAttest(appAttestCeremony.attest(payload: params.json))
  }

  public func prepareDeviceAssertion(_ params: DeviceAttestParams) async throws -> DeviceAssertionProof {
    try await mapAppAttest(appAttestCeremony.assert(payload: params.json))
  }

  private func mapAppAttest<Value>(_ result: Result<Value, ClerkJSAppAttestError>) throws -> Value {
    switch result {
    case .success(let value):
      return value
    case .failure(let error):
      if error.code == ClerkJSAppAttestError.cancelled.code {
        throw ClerkJSCoreError.cancelled
      }
      if error.code == ClerkJSAppAttestError.invalidPayload.code {
        throw ClerkJSCoreError.invalidArgument("appAttest")
      }
      throw ClerkJSCoreError.javascript(error.message)
    }
  }

  static func oauthAllowedRedirectProtocol(from url: URL) -> String {
    let scheme = url.scheme ?? "clerk"
    return scheme.hasSuffix(":") ? scheme : "\(scheme):"
  }

  static func oauthTransportInstallSource(redirectURL: URL) -> String {
    let encoded: String = if let data = try? JSONEncoder().encode(redirectURL.absoluteString),
       let text = String(data: data, encoding: .utf8)
    {
      text
    } else {
      "\"\""
    }
    return """
      {
        getRedirectUrl: function() { return \(encoded); },
        open: async function(url, options) {
          var href = (url && typeof url.href === 'string') ? url.href : String(url);
          var callbackUrl = await __clerkNativeOAuthOpen(href, options);
          return { callbackUrl: callbackUrl };
        }
      }
      """
  }

  private static func jsonString(_ value: String) throws -> String {
    let data = try JSONEncoder().encode(value)
    guard let encoded = String(data: data, encoding: .utf8) else {
      throw ClerkJSCoreError.invalidArgument(value)
    }
    return encoded
  }
  #endif
}
