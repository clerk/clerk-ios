@_exported import ClerkSnapshots
import ClerkWatchCompanion
import CryptoKit
import Foundation

private typealias FAPIClient = Client
private typealias FAPISignIn = SignIn
private typealias FAPISignUp = SignUp

private struct EmptyArgs: Encodable {}

package enum ClerkJSUserJSON {
  static func totpForKit(_ data: Data) -> Data {
    guard var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return data
    }
    object["created_at"] = unixMilliseconds(object["created_at"] ?? object["createdAt"]) ?? 0
    object["updated_at"] = unixMilliseconds(object["updated_at"] ?? object["updatedAt"]) ?? 0
    if object["backup_codes"] == nil, let codes = object["backupCodes"] {
      object["backup_codes"] = codes
    }
    object["createdAt"] = nil
    object["updatedAt"] = nil
    object["backupCodes"] = nil
    object["pathRoot"] = nil
    return (try? JSONSerialization.data(withJSONObject: object)) ?? data
  }

  static func backupCodesForKit(_ data: Data) -> Data {
    totpForKit(data)
  }

  private static func unixMilliseconds(_ value: Any?) -> Double? {
    switch value {
    case let number as NSNumber:
      return number.doubleValue
    case let string as String:
      let withFractional = ISO8601DateFormatter()
      withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      let date = withFractional.date(from: string) ?? ISO8601DateFormatter().date(from: string)
      return date.map { $0.timeIntervalSince1970 * 1000 }
    default:
      return nil
    }
  }
}

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

  static func signUpNamed(_ method: String) -> String {
    "\(instance).client.signUp.\(method)"
  }

  static func session(_ method: SessionJSMethod) -> String {
    "\(instance).session.\(method.rawValue)"
  }

  static func user(_ method: UserJSMethod) -> String {
    "\(instance).user.\(method.rawValue)"
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

  package static func snapshotEnvironmentJSON() throws -> Data {
    guard let url = Bundle.module.url(forResource: "environment-snapshot", withExtension: "json") else {
      throw ClerkJSCoreError.missingBundle
    }
    return try Data(contentsOf: url)
  }

  package static func snapshotEnvironment() throws -> Environment {
    try JSONDecoder().decode(Environment.self, from: snapshotEnvironmentJSON())
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

  public var user: User {
    User(clerk: self)
  }

  package var lastClientJSON: Data? {
    runtime.lastFAPIClientJSON
  }

  package var lastEnvironmentJSON: Data? {
    runtime.lastFAPIEnvironmentJSON
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

  public func signOut(_ options: SignOutOptions? = nil) async throws {
    if let options {
      _ = try await runtime.call(methodPath: ClerkJSPath.clerk(.signOut), args: options)
    } else {
      _ = try await runtime.call(methodPath: ClerkJSPath.clerk(.signOut), args: EmptyArgs())
    }
    try publishLastClient()
    publishLastEnvironment()
  }

  public func createOrganization(_ params: CreateOrganizationParams) async throws -> Data {
    try await callReturningAndPublish(ClerkJSPath.clerk(.createOrganization), params)
  }

  public func getOrganization(_ organizationId: String) async throws -> Data {
    try await callReturningAndPublish(ClerkJSPath.clerk(.getOrganization), organizationId)
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
    public var organization: String?

    public init(session: String?, organization: String? = nil) {
      self.session = session
      self.organization = organization
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encodeIfPresent(session, forKey: .session)
      try container.encodeIfPresent(organization, forKey: .organization)
    }

    private enum CodingKeys: String, CodingKey {
      case session
      case organization
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
    public func authenticateWithPasskey(
      _ params: AuthenticateWithPasskeyParams = AuthenticateWithPasskeyParams(flow: nil)
    ) async throws -> SignIn {
      try await clerk.callAndPublish(ClerkJSPath.signIn(.authenticateWithPasskey), params)
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
      public var password: String?
      public var ticket: String?
      public var token: String?
      public var transfer: Bool?

      public init(
        identifier: String? = nil,
        strategy: String? = nil,
        redirectUrl: String? = nil,
        password: String? = nil,
        ticket: String? = nil,
        token: String? = nil,
        transfer: Bool? = nil
      ) {
        self.identifier = identifier
        self.strategy = strategy
        self.redirectUrl = redirectUrl
        self.password = password
        self.ticket = ticket
        self.token = token
        self.transfer = transfer
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(identifier, forKey: .identifier)
        try container.encodeIfPresent(strategy, forKey: .strategy)
        try container.encodeIfPresent(redirectUrl, forKey: .redirectUrl)
        try container.encodeIfPresent(password, forKey: .password)
        try container.encodeIfPresent(ticket, forKey: .ticket)
        try container.encodeIfPresent(token, forKey: .token)
        try container.encodeIfPresent(transfer, forKey: .transfer)
      }

      private enum CodingKeys: String, CodingKey {
        case identifier
        case strategy
        case redirectUrl
        case password
        case ticket
        case token
        case transfer
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
      public var redirectUrl: String?
      public var codeChallenge: String?
      public var codeChallengeMethod: String?

      public init(
        strategy: Strategy,
        emailAddressId: String? = nil,
        phoneNumberId: String? = nil,
        redirectUrl: String? = nil,
        codeChallenge: String? = nil,
        codeChallengeMethod: String? = nil
      ) {
        self.strategy = strategy
        self.emailAddressId = emailAddressId
        self.phoneNumberId = phoneNumberId
        self.redirectUrl = redirectUrl
        self.codeChallenge = codeChallenge
        self.codeChallengeMethod = codeChallengeMethod
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encodeIfPresent(emailAddressId, forKey: .emailAddressId)
        try container.encodeIfPresent(phoneNumberId, forKey: .phoneNumberId)
        try container.encodeIfPresent(redirectUrl, forKey: .redirectUrl)
        try container.encodeIfPresent(codeChallenge, forKey: .codeChallenge)
        try container.encodeIfPresent(codeChallengeMethod, forKey: .codeChallengeMethod)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case emailAddressId
        case phoneNumberId
        case redirectUrl
        case codeChallenge
        case codeChallengeMethod
      }
    }

    public struct AttemptFirstFactorParams: Encodable, Sendable {
      public var strategy: Strategy
      public var code: String?
      public var password: String?
      public var token: String?

      public init(
        strategy: Strategy,
        code: String? = nil,
        password: String? = nil,
        token: String? = nil
      ) {
        self.strategy = strategy
        self.code = code
        self.password = password
        self.token = token
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encodeIfPresent(code, forKey: .code)
        try container.encodeIfPresent(password, forKey: .password)
        try container.encodeIfPresent(token, forKey: .token)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case code
        case password
        case token
      }
    }

    public enum Strategy: String, Encodable, Sendable {
      case emailCode = "email_code"
      case emailLink = "email_link"
      case phoneCode = "phone_code"
      case password
      case resetPasswordEmailCode = "reset_password_email_code"
      case resetPasswordPhoneCode = "reset_password_phone_code"
      case oauthTokenApple = "oauth_token_apple"
      case enterpriseSSO = "enterprise_sso"
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

    public func authenticateWithRedirect(_ params: AuthenticateWithRedirectParams) async throws {
      try await clerk.callAndPublish(
        ClerkJSPath.signUpNamed("authenticateWithRedirect"),
        params
      )
    }

    public struct AuthenticateWithRedirectParams: Encodable, Sendable {
      public var strategy: String
      public var redirectUrl: String
      public var emailAddress: String?

      public init(strategy: String, redirectUrl: String, emailAddress: String? = nil) {
        self.strategy = strategy
        self.redirectUrl = redirectUrl
        self.emailAddress = emailAddress
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encode(redirectUrl, forKey: .redirectUrl)
        try container.encodeIfPresent(emailAddress, forKey: .emailAddress)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case redirectUrl
        case emailAddress
      }
    }

    public struct CreateParams: Encodable, Sendable {
      public var emailAddress: String?
      public var phoneNumber: String?
      public var username: String?
      public var password: String?
      public var firstName: String?
      public var lastName: String?
      public var legalAccepted: Bool?
      public var transfer: Bool?
      public var ticket: String?
      public var token: String?
      public var strategy: String?
      public var unsafeMetadata: JSONValue?

      public init(
        emailAddress: String? = nil,
        phoneNumber: String? = nil,
        username: String? = nil,
        password: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        legalAccepted: Bool? = nil,
        transfer: Bool? = nil,
        ticket: String? = nil,
        token: String? = nil,
        strategy: String? = nil,
        unsafeMetadata: JSONValue? = nil
      ) {
        self.emailAddress = emailAddress
        self.phoneNumber = phoneNumber
        self.username = username
        self.password = password
        self.firstName = firstName
        self.lastName = lastName
        self.legalAccepted = legalAccepted
        self.transfer = transfer
        self.ticket = ticket
        self.token = token
        self.strategy = strategy
        self.unsafeMetadata = unsafeMetadata
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
        try container.encodeIfPresent(transfer, forKey: .transfer)
        try container.encodeIfPresent(ticket, forKey: .ticket)
        try container.encodeIfPresent(token, forKey: .token)
        try container.encodeIfPresent(strategy, forKey: .strategy)
        try container.encodeIfPresent(unsafeMetadata, forKey: .unsafeMetadata)
      }

      private enum CodingKeys: String, CodingKey {
        case emailAddress
        case phoneNumber
        case username
        case password
        case firstName
        case lastName
        case legalAccepted
        case transfer
        case ticket
        case token
        case strategy
        case unsafeMetadata
      }
    }

    public enum Strategy: String, Encodable, Sendable {
      case emailCode = "email_code"
      case emailLink = "email_link"
      case phoneCode = "phone_code"
    }

    public struct PrepareVerificationParams: Encodable, Sendable {
      public var strategy: Strategy
      public var redirectUrl: String?
      public var codeChallenge: String?
      public var codeChallengeMethod: String?

      public init(
        strategy: Strategy,
        redirectUrl: String? = nil,
        codeChallenge: String? = nil,
        codeChallengeMethod: String? = nil
      ) {
        self.strategy = strategy
        self.redirectUrl = redirectUrl
        self.codeChallenge = codeChallenge
        self.codeChallengeMethod = codeChallengeMethod
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encodeIfPresent(redirectUrl, forKey: .redirectUrl)
        try container.encodeIfPresent(codeChallenge, forKey: .codeChallenge)
        try container.encodeIfPresent(codeChallengeMethod, forKey: .codeChallengeMethod)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case redirectUrl
        case codeChallenge
        case codeChallengeMethod
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

    public var user: ClerkSnapshots.User? {
      lastActiveSession?.user
    }

    private var lastActiveSession: Session? {
      guard let client = clerk.fapiClient else { return nil }
      guard let sessionId = client.lastActiveSessionId else { return nil }
      return client.sessions.first { $0.id == sessionId }
    }

    public func getToken(_ params: GetTokenParams = .init()) async throws -> String? {
      let json = try await clerk.runtime.call(
        methodPath: ClerkJSPath.session(.getToken),
        args: params
      )
      if json == "null" {
        return nil
      }
      return try JSONDecoder().decode(String.self, from: Data(json.utf8))
    }

    public func startVerification(_ params: StartVerificationParams) async throws -> Data {
      try await clerk.callReturningAndPublish(ClerkJSPath.session(.startVerification), params)
    }

    public func prepareFirstFactorVerification(
      _ params: PrepareFirstFactorVerificationParams
    ) async throws -> Data {
      try await clerk.callReturningAndPublish(
        ClerkJSPath.session(.prepareFirstFactorVerification),
        params
      )
    }

    public func attemptFirstFactorVerification(
      _ params: AttemptFirstFactorVerificationParams
    ) async throws -> Data {
      try await clerk.callReturningAndPublish(
        ClerkJSPath.session(.attemptFirstFactorVerification),
        params
      )
    }

    public func prepareSecondFactorVerification(
      _ params: PrepareSecondFactorVerificationParams
    ) async throws -> Data {
      try await clerk.callReturningAndPublish(
        ClerkJSPath.session(.prepareSecondFactorVerification),
        params
      )
    }

    public func attemptSecondFactorVerification(
      _ params: AttemptSecondFactorVerificationParams
    ) async throws -> Data {
      try await clerk.callReturningAndPublish(
        ClerkJSPath.session(.attemptSecondFactorVerification),
        params
      )
    }

    public func verifyWithPasskey() async throws -> Data {
      try await clerk.callReturningAndPublish(ClerkJSPath.session(.verifyWithPasskey), EmptyArgs())
    }

    public struct GetTokenParams: Encodable, Sendable {
      public var template: String?
      public var skipCache: Bool?

      public init(template: String? = nil, skipCache: Bool? = nil) {
        self.template = template
        self.skipCache = skipCache
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(template, forKey: .template)
        try container.encodeIfPresent(skipCache, forKey: .skipCache)
      }

      private enum CodingKeys: String, CodingKey {
        case template
        case skipCache
      }
    }

    public struct StartVerificationParams: Encodable, Sendable {
      public var level: String

      public init(level: String) {
        self.level = level
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(level, forKey: .level)
      }

      private enum CodingKeys: String, CodingKey {
        case level
      }
    }

    public struct PrepareFirstFactorVerificationParams: Encodable, Sendable {
      public var strategy: String
      public var emailAddressId: String?
      public var phoneNumberId: String?
      public var enterpriseConnectionId: String?
      public var redirectUrl: String?

      public init(
        strategy: String,
        emailAddressId: String? = nil,
        phoneNumberId: String? = nil,
        enterpriseConnectionId: String? = nil,
        redirectUrl: String? = nil
      ) {
        self.strategy = strategy
        self.emailAddressId = emailAddressId
        self.phoneNumberId = phoneNumberId
        self.enterpriseConnectionId = enterpriseConnectionId
        self.redirectUrl = redirectUrl
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encodeIfPresent(emailAddressId, forKey: .emailAddressId)
        try container.encodeIfPresent(phoneNumberId, forKey: .phoneNumberId)
        try container.encodeIfPresent(enterpriseConnectionId, forKey: .enterpriseConnectionId)
        try container.encodeIfPresent(redirectUrl, forKey: .redirectUrl)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case emailAddressId
        case phoneNumberId
        case enterpriseConnectionId
        case redirectUrl
      }
    }

    public struct AttemptFirstFactorVerificationParams: Encodable, Sendable {
      public var strategy: String
      public var code: String?
      public var password: String?
      public var publicKeyCredential: String?

      public init(
        strategy: String,
        code: String? = nil,
        password: String? = nil,
        publicKeyCredential: String? = nil
      ) {
        self.strategy = strategy
        self.code = code
        self.password = password
        self.publicKeyCredential = publicKeyCredential
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encodeIfPresent(code, forKey: .code)
        try container.encodeIfPresent(password, forKey: .password)
        try container.encodeIfPresent(publicKeyCredential, forKey: .publicKeyCredential)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case code
        case password
        case publicKeyCredential
      }
    }

    public struct PrepareSecondFactorVerificationParams: Encodable, Sendable {
      public var strategy: String
      public var phoneNumberId: String?

      public init(strategy: String, phoneNumberId: String? = nil) {
        self.strategy = strategy
        self.phoneNumberId = phoneNumberId
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encodeIfPresent(phoneNumberId, forKey: .phoneNumberId)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case phoneNumberId
      }
    }

    public struct AttemptSecondFactorVerificationParams: Encodable, Sendable {
      public var strategy: String
      public var code: String?
      public var publicKeyCredential: String?

      public init(
        strategy: String,
        code: String? = nil,
        publicKeyCredential: String? = nil
      ) {
        self.strategy = strategy
        self.code = code
        self.publicKeyCredential = publicKeyCredential
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encodeIfPresent(code, forKey: .code)
        try container.encodeIfPresent(publicKeyCredential, forKey: .publicKeyCredential)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case code
        case publicKeyCredential
      }
    }
  }

  @MainActor
  public struct User {
    unowned let clerk: Clerk

    @discardableResult
    public func update(_ params: UpdateUserParams) async throws -> ClerkSnapshots.User? {
      try await clerk.callAndPublish(ClerkJSPath.user(.update), params)
      return clerk.session.user
    }

    public func updatePassword(_ params: UpdateUserPasswordParams) async throws {
      try await clerk.callAndPublish(ClerkJSPath.user(.updatePassword), params)
    }

    public func createEmailAddress(_ params: CreateEmailAddressParams) async throws {
      try await clerk.callAndPublish(ClerkJSPath.user(.createEmailAddress), params)
    }

    public func createPhoneNumber(_ params: CreatePhoneNumberParams) async throws {
      try await clerk.callAndPublish(ClerkJSPath.user(.createPhoneNumber), params)
    }

    public func createTOTP() async throws -> Data {
      let data = try await clerk.callReturningAndPublish(ClerkJSPath.user(.createTOTP), EmptyArgs())
      return ClerkJSUserJSON.totpForKit(data)
    }

    public func verifyTOTP(_ params: VerifyTOTPParams) async throws -> Data {
      let data = try await clerk.callReturningAndPublish(ClerkJSPath.user(.verifyTOTP), params)
      return ClerkJSUserJSON.totpForKit(data)
    }

    public func delete() async throws -> Data {
      try await clerk.callReturningAndPublish(ClerkJSPath.user(.delete), EmptyArgs())
    }

    public func reload() async throws {
      try await clerk.callAndPublish(ClerkJSPath.user(.reload), EmptyArgs())
    }

    public func updateMetadata(_ params: UpdateUserMetadataParams) async throws {
      try await clerk.callAndPublish(ClerkJSPath.user(.updateMetadata), params)
    }

    public func createBackupCode() async throws -> Data {
      let data = try await clerk.callReturningAndPublish(ClerkJSPath.user(.createBackupCode), EmptyArgs())
      return ClerkJSUserJSON.backupCodesForKit(data)
    }

    public func disableTOTP() async throws -> Data {
      try await clerk.callReturningAndPublish(ClerkJSPath.user(.disableTOTP), EmptyArgs())
    }

    public func createExternalAccount(_ params: ExternalAccountParams) async throws {
      try await clerk.callAndPublish(ClerkJSPath.user(.createExternalAccount), params)
    }

    public func createPasskey() async throws {
      try await clerk.callAndPublish(ClerkJSPath.user(.createPasskey), EmptyArgs())
    }

    public struct ExternalAccountParams: Encodable, Sendable {
      public var strategy: String?
      public var redirectUrl: String?
      public var additionalScopes: [String]?
      public var oidcPrompt: String?
      public var token: String?

      public init(
        strategy: String? = nil,
        redirectUrl: String? = nil,
        additionalScopes: [String]? = nil,
        oidcPrompt: String? = nil,
        token: String? = nil
      ) {
        self.strategy = strategy
        self.redirectUrl = redirectUrl
        self.additionalScopes = additionalScopes
        self.oidcPrompt = oidcPrompt
        self.token = token
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(strategy, forKey: .strategy)
        try container.encodeIfPresent(redirectUrl, forKey: .redirectUrl)
        try container.encodeIfPresent(additionalScopes, forKey: .additionalScopes)
        try container.encodeIfPresent(oidcPrompt, forKey: .oidcPrompt)
        try container.encodeIfPresent(token, forKey: .token)
      }

      private enum CodingKeys: String, CodingKey {
        case strategy
        case redirectUrl
        case additionalScopes
        case oidcPrompt
        case token
      }
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

  private func callReturningAndPublish(_ methodPath: String, _ args: some Encodable & Sendable) async throws -> Data {
    let json: String
    do {
      json = try await runtime.callReturning(methodPath: methodPath, args: args)
    } catch {
      try? publishLastClient()
      publishLastEnvironment()
      throw error
    }
    try publishLastClient()
    publishLastEnvironment()
    return Data(json.utf8)
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
