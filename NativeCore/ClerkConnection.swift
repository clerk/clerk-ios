import Foundation

public struct ClerkConfiguration: Sendable {
  public let publishableKey: String
  public let callbackURL: URL
  public let frontendAPI: URL
  public let legacyKeychain: LegacyKeychainConfiguration
  public init(publishableKey: String, callbackURL: URL, legacyKeychain: LegacyKeychainConfiguration = .init()) throws {
    let key = publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard key.hasPrefix("pk_test_") || key.hasPrefix("pk_live_") else { throw CoreError(code: "invalid_publishable_key") }
    var encoded = String(key.dropFirst(8)).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
    guard let data = Data(base64Encoded: encoded), let decoded = String(data: data, encoding: .utf8), decoded.hasSuffix("$"),
          let origin = URL(string: "https://\(decoded.dropLast())"), origin.host != nil, origin.user == nil, origin.password == nil,
          origin.path.isEmpty, origin.query == nil, origin.fragment == nil else { throw CoreError(code: "invalid_publishable_key") }
    guard let scheme = callbackURL.scheme, !["http", "javascript", "data", "file", "about"].contains(scheme.lowercased()),
          callbackURL.host != nil, callbackURL.user == nil, callbackURL.password == nil, callbackURL.fragment == nil else { throw CoreError(code: "invalid_callback_url") }
    self.publishableKey = key; self.callbackURL = callbackURL; frontendAPI = origin; self.legacyKeychain = legacyKeychain
  }
}

extension Clerk {
  @MainActor public static func connect(configuration: ClerkConfiguration, storage: (any CredentialStorage)? = nil, browser: AppleCapabilities.Presentation? = nil, passkeys: AppleCapabilities.Presentation? = nil, appleIdentity: AppleCapabilities.Presentation? = nil, passkeyAutofill: Bool = false, authStorage: (any CredentialStorage)? = nil, biometrics: AppleBiometricCapabilities? = nil) async throws -> Clerk {
    let storage = storage ?? KeychainCredentialStorage(publishableKey: configuration.publishableKey, frontendAPI: configuration.frontendAPI, legacy: configuration.legacyKeychain)
    let authStorage = authStorage ?? KeychainCredentialStorage(publishableKey: configuration.publishableKey, frontendAPI: configuration.frontendAPI, legacy: configuration.legacyKeychain, purpose: .magicLink)
    let biometrics = biometrics ?? AppleBiometricCapabilities(
      publishableKey: configuration.publishableKey,
      credentials: KeychainCredentialStorage(publishableKey: configuration.publishableKey, frontendAPI: configuration.frontendAPI, legacy: configuration.legacyKeychain, purpose: .biometricCredentials),
      cleanup: KeychainCredentialStorage(publishableKey: configuration.publishableKey, frontendAPI: configuration.frontendAPI, legacy: configuration.legacyKeychain, purpose: .biometricCleanup),
      legacyKeychain: configuration.legacyKeychain
    )
    let capabilities = try AppleCapabilities(publishableKey: configuration.publishableKey, frontendAPI: configuration.frontendAPI, storage: storage, browser: browser, passkeys: passkeys, appleIdentity: appleIdentity, passkeyAutofill: passkeyAutofill, authStorage: authStorage, biometrics: biometrics)
    return try await connect(configuration: configuration, capabilities: capabilities)
  }

  @MainActor public static func connect(configuration: ClerkConfiguration, capabilities: any NativeCapabilities) async throws -> Clerk {
    try await connect(configuration: configuration, capabilities: capabilities, observeConnectivity: { observeNetworkConnectivity($0) })
  }

  @MainActor static func connect(configuration: ClerkConfiguration, capabilities: any NativeCapabilities, observeConnectivity: (CoreRuntime) -> Void) async throws -> Clerk {
    #if SWIFT_PACKAGE && canImport(JavaScriptCore)
    guard let url = Bundle.module.url(forResource: "clerk-core", withExtension: "js") else { throw CoreError(code: "missing_core_bundle") }
    let bundle = try Data(contentsOf: url)
    let transport = JavaScriptCoreTransport(capabilities: capabilities)
    let runtime = CoreRuntime(transport: transport)
    do {
      try await transport.start(bundle: bundle, sha256: BundledCore.sha256)
      try await runtime.initialize(publishableKey: configuration.publishableKey, callbackURL: configuration.callbackURL, platform: "ios", capabilities: capabilities.supported, sdkVersion: Clerk.sdkVersion)
      guard let clerk = try runtime.root("clerk", as: Clerk.self) else { throw CoreError(code: "missing_clerk_root") }
      observeApplicationLifecycle(runtime)
      observeConnectivity(runtime)
      return clerk
    } catch { runtime.close(); throw error }
    #elseif !canImport(JavaScriptCore)
    throw CoreError(code: "capability_unavailable:embedded_engine")
    #else
    throw CoreError(code: "missing_package_resources")
    #endif
  }

  @MainActor public func close() {
    try? context.requireRuntime().close()
  }
}
