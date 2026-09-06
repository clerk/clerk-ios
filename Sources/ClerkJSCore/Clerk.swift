import CryptoKit
import Foundation

private typealias FAPIClient = Client
private typealias FAPISignIn = SignIn

private struct EmptyArgs: Encodable {}

public final class Clerk: @unchecked Sendable {
  private let publishableKey: String
  package let runtime: ClerkJSRuntime
  private var fapiClient: FAPIClient?

  public init(
    publishableKey: String,
    tokenCache: ClerkJSTokenCache = .memory(),
    resourceCache: ClerkJSResourceCache? = nil
  ) {
    self.publishableKey = publishableKey
    runtime = ClerkJSRuntime(tokenCache: tokenCache, resourceCache: resourceCache)
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
      )
    )
  }

  static func storageNamespace(for publishableKey: String) -> String {
    SHA256.hash(data: Data(publishableKey.utf8))
      .prefix(8)
      .map { String(format: "%02x", $0) }
      .joined()
  }

  public var client: Client {
    Client(clerk: self)
  }

  public var session: ActiveSession {
    ActiveSession(clerk: self)
  }

  public func load() async throws {
    try await runtime.load(publishableKey: publishableKey)
    try publishLastClient()
  }

  public func setActive(_ params: SetActiveParams) async throws {
    _ = try await runtime.call(methodPath: "__clerkInstance.setActive", args: params)
    try publishLastClient()
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

  public struct SetActiveParams: Encodable, Sendable {
    public var session: String?

    public init(session: String?) {
      self.session = session
    }
  }

  public struct Client: @unchecked Sendable {
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

  public struct SignIn: @unchecked Sendable {
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
      try await clerk.callAndPublish("__clerkInstance.client.signIn.create", params)
      return clerk.client.signIn
    }

    @discardableResult
    public func prepareFirstFactor(_ params: PrepareFirstFactorParams) async throws -> SignIn {
      try await clerk.callAndPublish("__clerkInstance.client.signIn.prepareFirstFactor", params)
      return clerk.client.signIn
    }

    @discardableResult
    public func attemptFirstFactor(_ params: AttemptFirstFactorParams) async throws -> SignIn {
      try await clerk.callAndPublish("__clerkInstance.client.signIn.attemptFirstFactor", params)
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

  public struct ActiveSession: @unchecked Sendable {
    unowned let clerk: Clerk

    public func getToken() async throws -> String {
      let json = try await clerk.runtime.call(
        methodPath: "__clerkInstance.session.getToken",
        args: EmptyArgs()
      )
      return try JSONDecoder().decode(String.self, from: Data(json.utf8))
    }
  }

  private func callAndPublish(_ methodPath: String, _ args: some Encodable) async throws {
    do {
      _ = try await runtime.call(methodPath: methodPath, args: args)
    } catch {
      try? publishLastClient()
      throw error
    }
    try publishLastClient()
  }

  private func publishLastClient() throws {
    guard let data = runtime.lastFAPIClientJSON else {
      throw ClerkJSCoreError.invalidArgument("lastFAPIClientJSON")
    }
    fapiClient = try FAPIJSON.decodeClient(data)
  }
}
