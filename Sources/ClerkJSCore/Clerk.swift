@_exported import ClerkSnapshots
import ClerkWatchCompanion
import CryptoKit
import Foundation

private typealias FAPIClient = Client
private typealias FAPISignIn = SignIn
private typealias FAPISignUp = SignUp

private struct EmptyArgs: Encodable {}

package enum ClerkJSPath {
  private static let instance = "__clerkInstance"

  static func clerk(_ method: ClerkJSMethod) -> String {
    "\(instance).\(method.rawValue)"
  }

  static func signIn(_ method: SignInJSMethod) -> String {
    "\(instance).client.signIn.\(method.rawValue)"
  }

  static func signInNamed(_ method: String) -> String {
    "\(instance).client.signIn.\(method)"
  }

  static func signUp(_ method: SignUpJSMethod) -> String {
    "\(instance).client.signUp.\(method.rawValue)"
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

  package func publishClient(_ data: Data) throws {
    fapiClient = try FAPIJSON.decodeClient(data)
  }

  package static func snapshotEnvironment() throws -> Environment {
    guard let url = Bundle.module.url(forResource: "environment-snapshot", withExtension: "json") else {
      throw ClerkJSCoreError.missingBundle
    }
    return try JSONDecoder().decode(Environment.self, from: Data(contentsOf: url))
  }

  package static func snapshotSignedInClient() throws -> Data {
    guard let url = Bundle.module.url(forResource: "signed-in-client", withExtension: "json") else {
      throw ClerkJSCoreError.missingBundle
    }
    return try Data(contentsOf: url)
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

  public var user: User? {
    session.user
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

    public var signUp: SignUp {
      SignUp(clerk: clerk)
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

    public var supportedSecondFactors: [SignInSecondFactor] {
      model?.supportedSecondFactors ?? []
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

    @discardableResult
    public func prepareSecondFactor(_ params: PrepareSecondFactorParams) async throws -> SignIn {
      try await clerk.callAndPublish(ClerkJSPath.signIn(.prepareSecondFactor), params)
      return clerk.client.signIn
    }

    @discardableResult
    public func attemptSecondFactor(_ params: AttemptSecondFactorParams) async throws -> SignIn {
      try await clerk.callAndPublish(ClerkJSPath.signIn(.attemptSecondFactor), params)
      return clerk.client.signIn
    }

    @discardableResult
    public func resetPassword(_ params: ResetPasswordParams) async throws -> SignIn {
      try await clerk.callAndPublish(ClerkJSPath.signIn(.resetPassword), params)
      return clerk.client.signIn
    }

    public func authenticateWithRedirect(_ params: AuthenticateWithRedirectParams) async throws {
      try await clerk.callAndPublish(
        ClerkJSPath.signInNamed("authenticateWithRedirect"),
        params
      )
    }

    public struct CreateParams: Encodable, Sendable {
      public var identifier: String?
      public var strategy: String?
      public var redirectUrl: String?

      public init(
        identifier: String? = nil,
        strategy: String? = nil,
        redirectUrl: String? = nil
      ) {
        self.identifier = identifier
        self.strategy = strategy
        self.redirectUrl = redirectUrl
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(identifier, forKey: .identifier)
        try container.encodeIfPresent(strategy, forKey: .strategy)
        try container.encodeIfPresent(redirectUrl, forKey: .redirectUrl)
      }

      private enum CodingKeys: String, CodingKey {
        case identifier
        case strategy
        case redirectUrl
      }
    }

    public struct AuthenticateWithRedirectParams: Encodable, Sendable {
      public var strategy: String
      public var redirectUrl: String
      public var identifier: String?

      public init(strategy: String, redirectUrl: String, identifier: String? = nil) {
        self.strategy = strategy
        self.redirectUrl = redirectUrl
        self.identifier = identifier
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encode(redirectUrl, forKey: .redirectUrl)
        try container.encodeIfPresent(identifier, forKey: .identifier)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case redirectUrl
        case identifier
      }
    }

    public struct PrepareFirstFactorParams: Encodable, Sendable {
      public var strategy: Strategy
      public var emailAddressId: String?
      public var phoneNumberId: String?

      public init(
        strategy: Strategy,
        emailAddressId: String? = nil,
        phoneNumberId: String? = nil
      ) {
        self.strategy = strategy
        self.emailAddressId = emailAddressId
        self.phoneNumberId = phoneNumberId
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encodeIfPresent(emailAddressId, forKey: .emailAddressId)
        try container.encodeIfPresent(phoneNumberId, forKey: .phoneNumberId)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case emailAddressId
        case phoneNumberId
      }
    }

    public struct AttemptFirstFactorParams: Encodable, Sendable {
      public var strategy: Strategy
      public var code: String?
      public var password: String?

      public init(strategy: Strategy, code: String? = nil, password: String? = nil) {
        self.strategy = strategy
        self.code = code
        self.password = password
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encodeIfPresent(code, forKey: .code)
        try container.encodeIfPresent(password, forKey: .password)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case code
        case password
      }
    }

    public enum Strategy: String, Encodable, Sendable {
      case emailCode = "email_code"
      case phoneCode = "phone_code"
      case password
      case resetPasswordEmailCode = "reset_password_email_code"
      case resetPasswordPhoneCode = "reset_password_phone_code"
    }

    public enum SecondFactorStrategy: String, Encodable, Sendable {
      case emailCode = "email_code"
      case phoneCode = "phone_code"
      case totp
      case backupCode = "backup_code"
    }

    public struct PrepareSecondFactorParams: Encodable, Sendable {
      public var strategy: SecondFactorStrategy
      public var emailAddressId: String?
      public var phoneNumberId: String?

      public init(
        strategy: SecondFactorStrategy,
        emailAddressId: String? = nil,
        phoneNumberId: String? = nil
      ) {
        self.strategy = strategy
        self.emailAddressId = emailAddressId
        self.phoneNumberId = phoneNumberId
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encodeIfPresent(emailAddressId, forKey: .emailAddressId)
        try container.encodeIfPresent(phoneNumberId, forKey: .phoneNumberId)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case emailAddressId
        case phoneNumberId
      }
    }

    public struct AttemptSecondFactorParams: Encodable, Sendable {
      public var strategy: SecondFactorStrategy
      public var code: String

      public init(strategy: SecondFactorStrategy, code: String) {
        self.strategy = strategy
        self.code = code
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encode(code, forKey: .code)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case code
      }
    }

    public struct ResetPasswordParams: Encodable, Sendable {
      public var password: String
      public var signOutOfOtherSessions: Bool?

      public init(password: String, signOutOfOtherSessions: Bool? = nil) {
        self.password = password
        self.signOutOfOtherSessions = signOutOfOtherSessions
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(password, forKey: .password)
        try container.encodeIfPresent(signOutOfOtherSessions, forKey: .signOutOfOtherSessions)
      }

      private enum CodingKeys: String, CodingKey {
        case password
        case signOutOfOtherSessions
      }
    }

    private var model: FAPISignIn? {
      clerk.fapiClient?.signIn
    }
  }

  @MainActor
  public struct SignUp {
    unowned let clerk: Clerk

    public var id: String? {
      model?.id
    }

    public var status: SignUpStatus? {
      model?.status
    }

    public var emailAddress: String? {
      model?.emailAddress
    }

    public var phoneNumber: String? {
      model?.phoneNumber
    }

    public var username: String? {
      model?.username
    }

    public var firstName: String? {
      model?.firstName
    }

    public var lastName: String? {
      model?.lastName
    }

    public var hasPassword: Bool {
      model?.hasPassword ?? false
    }

    public var missingFields: [String] {
      model?.missingFields ?? []
    }

    public var unverifiedFields: [String] {
      model?.unverifiedFields ?? []
    }

    public var requiredFields: [String] {
      model?.requiredFields ?? []
    }

    public var optionalFields: [String] {
      model?.optionalFields ?? []
    }

    public var createdSessionId: String? {
      model?.createdSessionId
    }

    @discardableResult
    public func create(_ params: CreateParams) async throws -> SignUp {
      try await clerk.callAndPublish(ClerkJSPath.signUp(.create), params)
      return clerk.client.signUp
    }

    @discardableResult
    public func update(_ params: CreateParams) async throws -> SignUp {
      try await clerk.callAndPublish(ClerkJSPath.signUp(.update), params)
      return clerk.client.signUp
    }

    @discardableResult
    public func prepareVerification(_ params: PrepareVerificationParams) async throws -> SignUp {
      try await clerk.callAndPublish(ClerkJSPath.signUp(.prepareVerification), params)
      return clerk.client.signUp
    }

    @discardableResult
    public func attemptVerification(_ params: AttemptVerificationParams) async throws -> SignUp {
      try await clerk.callAndPublish(ClerkJSPath.signUp(.attemptVerification), params)
      return clerk.client.signUp
    }

    public struct CreateParams: Encodable, Sendable {
      public var emailAddress: String?
      public var phoneNumber: String?
      public var username: String?
      public var password: String?
      public var firstName: String?
      public var lastName: String?
      public var legalAccepted: Bool?

      public init(
        emailAddress: String? = nil,
        phoneNumber: String? = nil,
        username: String? = nil,
        password: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        legalAccepted: Bool? = nil
      ) {
        self.emailAddress = emailAddress
        self.phoneNumber = phoneNumber
        self.username = username
        self.password = password
        self.firstName = firstName
        self.lastName = lastName
        self.legalAccepted = legalAccepted
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(emailAddress, forKey: .emailAddress)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(password, forKey: .password)
        try container.encodeIfPresent(firstName, forKey: .firstName)
        try container.encodeIfPresent(lastName, forKey: .lastName)
        try container.encodeIfPresent(legalAccepted, forKey: .legalAccepted)
      }

      private enum CodingKeys: String, CodingKey {
        case emailAddress
        case phoneNumber
        case username
        case password
        case firstName
        case lastName
        case legalAccepted
      }
    }

    public enum Strategy: String, Encodable, Sendable {
      case emailCode = "email_code"
      case emailLink = "email_link"
      case phoneCode = "phone_code"
    }

    public struct PrepareVerificationParams: Encodable, Sendable {
      public var strategy: Strategy

      public init(strategy: Strategy) {
        self.strategy = strategy
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
      }
    }

    public struct AttemptVerificationParams: Encodable, Sendable {
      public var strategy: Strategy
      public var code: String

      public init(strategy: Strategy, code: String) {
        self.strategy = strategy
        self.code = code
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encode(code, forKey: .code)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case code
      }
    }

    private var model: FAPISignUp? {
      clerk.fapiClient?.signUp
    }
  }

  @MainActor
  public struct ActiveSession {
    unowned let clerk: Clerk

    public var id: String? {
      lastActiveSession?.id
    }

    public var status: SessionStatus? {
      lastActiveSession?.status
    }

    public var user: User? {
      lastActiveSession?.user
    }

    private var lastActiveSession: Session? {
      guard let client = clerk.fapiClient else { return nil }
      guard let sessionId = client.lastActiveSessionId else { return nil }
      return client.sessions.first { $0.id == sessionId }
    }

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
