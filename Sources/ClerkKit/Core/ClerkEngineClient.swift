import ClerkSnapshots
import Foundation

private struct EmptyEngineArgs: Encodable {}

private struct OptionalPageArgs: Encodable {
  var initialPage: Int?
  var pageSize: Int?

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(initialPage, forKey: .initialPage)
    try container.encodeIfPresent(pageSize, forKey: .pageSize)
  }

  private enum CodingKeys: String, CodingKey {
    case initialPage
    case pageSize
  }
}

private struct BillingQueryArgs: Encodable {
  var id: String?
  var orgId: String?
  var initialPage: Int?
  var pageSize: Int?
  var minSeats: Int?
  var `for`: String?

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(id, forKey: .id)
    try container.encodeIfPresent(orgId, forKey: .orgId)
    try container.encodeIfPresent(initialPage, forKey: .initialPage)
    try container.encodeIfPresent(pageSize, forKey: .pageSize)
    try container.encodeIfPresent(minSeats, forKey: .minSeats)
    try container.encodeIfPresent(`for`, forKey: .for)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case orgId
    case initialPage
    case pageSize
    case minSeats
    case `for`
  }
}

private struct PasskeyFactorArgs: Encodable {
  var strategy: String
  var redirectUrl: String?
  var publicKeyCredential: String?

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(strategy, forKey: .strategy)
    try container.encodeIfPresent(redirectUrl, forKey: .redirectUrl)
    try container.encodeIfPresent(publicKeyCredential, forKey: .publicKeyCredential)
  }

  private enum CodingKeys: String, CodingKey {
    case strategy
    case redirectUrl
    case publicKeyCredential
  }
}

private struct ReloadArgs: Encodable {
  var rotatingTokenNonce: String?

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(rotatingTokenNonce, forKey: .rotatingTokenNonce)
  }

  private enum CodingKeys: String, CodingKey {
    case rotatingTokenNonce
  }
}

package enum ClerkInstanceRoot: String {
  case billing
  case signIn
  case signUp
  case user
}

@MainActor
package protocol ClerkEngineClient: AnyObject {
  func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue
  func signIn(identifier: String) async throws
  func signInWithEmailCode(emailAddress: String) async throws
  func signInWithPhoneCode(phoneNumber: String) async throws
  func signInWithPassword(identifier: String, password: String) async throws
  func sendEmailCode(emailAddressId: String?) async throws
  func sendEmailLink(
    emailAddressId: String?,
    redirectUrl: String,
    codeChallenge: String,
    codeChallengeMethod: String
  ) async throws
  func sendSignUpEmailLink(
    redirectUrl: String,
    codeChallenge: String,
    codeChallengeMethod: String
  ) async throws
  func sendPhoneCode(phoneNumberId: String?) async throws
  func verifyEmailCode(_ code: String) async throws
  func verifyPhoneCode(_ code: String) async throws
  func authenticateWithPassword(_ password: String) async throws
  func setActive(sessionId: String, organizationId: String?) async throws
  func signOut(sessionId: String?) async throws
  func getToken(template: String?, skipCache: Bool) async throws -> String?
  func signUp(
    emailAddress: String?,
    password: String?,
    firstName: String?,
    lastName: String?,
    username: String?,
    phoneNumber: String?,
    legalAccepted: Bool?,
    transfer: Bool
  ) async throws
  func sendSignUpEmailCode() async throws
  func sendSignUpPhoneCode() async throws
  func verifySignUpEmailCode(_ code: String) async throws
  func verifySignUpPhoneCode(_ code: String) async throws
  func authenticateWithRedirect(strategy: String, redirectUrl: String, identifier: String?) async throws
  func startEnterpriseSSO(emailAddress: String, redirectUrl: String) async throws
  func authenticateSignUpWithRedirect(strategy: String, redirectUrl: String, emailAddress: String?) async throws
  func signInWithTicket(_ ticket: String) async throws
  func signInWithIdToken(strategy: String, token: String) async throws
  func authenticateWithIdToken(strategy: String, token: String) async throws
  func signUpWithTicket(_ ticket: String) async throws
  func signUpWithIdToken(strategy: String, token: String, firstName: String?, lastName: String?) async throws
  func createPasskeySignIn() async throws
  func authenticateWithPasskey(autofill: Bool) async throws
  func sendMfaPhoneCode(phoneNumberId: String?) async throws
  func sendMfaEmailCode(emailAddressId: String?) async throws
  func verifyMfaCode(_ code: String, type: SignIn.MfaType) async throws
  func sendResetPasswordEmailCode(emailAddressId: String?) async throws
  func sendResetPasswordPhoneCode(phoneNumberId: String?) async throws
  func verifyResetPasswordCode(_ code: String, isEmail: Bool) async throws
  func resetPassword(password: String, signOutOfOtherSessions: Bool) async throws
  func updateSignUp(
    emailAddress: String?,
    password: String?,
    firstName: String?,
    lastName: String?,
    username: String?,
    phoneNumber: String?,
    legalAccepted: Bool?
  ) async throws
  func updateUser(username: String?, firstName: String?, lastName: String?, primaryEmailAddressId: String?, primaryPhoneNumberId: String?, unsafeMetadata: JSON?) async throws
  func updatePassword(currentPassword: String?, newPassword: String, signOutOfOtherSessions: Bool) async throws
  func createEmailAddress(_ emailAddress: String) async throws
  func createPhoneNumber(_ phoneNumber: String) async throws
  func createTOTP() async throws -> Data
  func verifyTOTP(code: String) async throws -> Data
  func deleteUser() async throws -> Data
  func reloadUser() async throws
  func updateUserMetadata(unsafeMetadata: JSON) async throws
  func createBackupCodes() async throws -> Data
  func disableTOTP() async throws -> Data
  func createExternalAccount(
    strategy: String,
    redirectUrl: String?,
    additionalScopes: [String],
    oidcPrompt: String?,
    token: String?
  ) async throws -> ExternalAccount
  func createPasskey() async throws -> Passkey
  func createOrganization(name: String, slug: String?) async throws -> Organization
  func getOrganization(id: String) async throws -> Organization
  func callInstance(root: String, method: String, args: Data) async throws -> Data
  func getOrganizationInvitations(page: Int, pageSize: Int, status: [String]) async throws -> Data
  func getOrganizationMemberships(page: Int, pageSize: Int) async throws -> Data
  func getOrganizationSuggestions(page: Int, pageSize: Int, status: [String]) async throws -> Data
  func getSessions() async throws -> Data
  func leaveOrganization(organizationId: String) async throws -> Data
  func getOrganizationCreationDefaults() async throws -> Data
  func transferToSignUp(unsafeMetadata: JSON?) async throws
  func transferToSignIn() async throws
  func startSessionVerification(level: String) async throws -> SessionVerification
  func prepareSessionFirstFactor(
    strategy: String,
    emailAddressId: String?,
    phoneNumberId: String?,
    enterpriseConnectionId: String?,
    redirectUrl: String?
  ) async throws -> SessionVerification
  func attemptSessionFirstFactor(
    strategy: String,
    code: String?,
    password: String?,
    publicKeyCredential: String?
  ) async throws -> SessionVerification
  func prepareSessionSecondFactor(strategy: String, phoneNumberId: String?) async throws -> SessionVerification
  func attemptSessionSecondFactor(
    strategy: String,
    code: String?,
    publicKeyCredential: String?
  ) async throws -> SessionVerification
  func verifySessionWithPasskey() async throws -> SessionVerification
}

extension Clerk {
  @MainActor
  package static var engineClient: (any ClerkEngineClient)?

  @MainActor
  package static var makeEngineClient: (@MainActor (Clerk) async -> any ClerkEngineClient)?

  @MainActor
  package static func resolvedEngineClient() async -> (any ClerkEngineClient)? {
    if let engineClient {
      return engineClient
    }
    guard let makeEngineClient else {
      return nil
    }
    let created = await makeEngineClient(shared)
    engineClient = created
    return created
  }

  @MainActor
  package static func callInstance(
    _ root: ClerkInstanceRoot,
    _ method: some RawRepresentable<String>,
    _ args: some Encodable = EmptyEngineArgs()
  ) async throws {
    let engine = try await requireEngineClient()
    _ = try await engine.callInstance(
      root: root.rawValue,
      method: method.rawValue,
      args: JSONEncoder().encode(args)
    )
  }

  @MainActor
  package static func callInstance<T: Decodable>(
    _ root: ClerkInstanceRoot,
    _ method: some RawRepresentable<String>,
    _ args: some Encodable = EmptyEngineArgs(),
    as _: T.Type
  ) async throws -> T {
    let engine = try await requireEngineClient()
    let data = try await engine.callInstance(
      root: root.rawValue,
      method: method.rawValue,
      args: JSONEncoder().encode(args)
    )
    return try JSONDecoder.clerkDecoder.decode(T.self, from: data)
  }

  @MainActor
  package static func getBillingPlans(_ params: GetPlansParams?) async throws -> ClerkPaginatedResponse<BillingPlan> {
    try await callInstance(
      .billing,
      BillingJSMethod.getPlans,
      BillingQueryArgs(
        id: nil,
        orgId: params?.orgId,
        initialPage: params?.initialPage,
        pageSize: params?.pageSize,
        minSeats: params?.minSeats,
        for: params?.for?.rawValue
      ),
      as: ClerkPaginatedResponse<BillingPlan>.self
    )
  }

  @MainActor
  package static func getBillingPlan(id: String) async throws -> BillingPlan {
    try await callInstance(
      .billing,
      BillingJSMethod.getPlan,
      BillingQueryArgs(id: id),
      as: BillingPlan.self
    )
  }

  @MainActor
  package static func getBillingSubscription(orgId: String?) async throws -> BillingSubscription {
    try await callInstance(
      .billing,
      BillingJSMethod.getSubscription,
      BillingQueryArgs(orgId: orgId),
      as: BillingSubscription.self
    )
  }

  @MainActor
  package static func getBillingStatements(
    orgId: String?,
    initialPage: Int?,
    pageSize: Int?
  ) async throws -> ClerkPaginatedResponse<BillingStatement> {
    try await callInstance(
      .billing,
      BillingJSMethod.getStatements,
      BillingQueryArgs(orgId: orgId, initialPage: initialPage, pageSize: pageSize),
      as: ClerkPaginatedResponse<BillingStatement>.self
    )
  }

  @MainActor
  package static func getBillingStatement(
    id: String,
    orgId: String?,
    initialPage: Int?,
    pageSize: Int?
  ) async throws -> BillingStatement {
    try await callInstance(
      .billing,
      BillingJSMethod.getStatement,
      BillingQueryArgs(id: id, orgId: orgId, initialPage: initialPage, pageSize: pageSize),
      as: BillingStatement.self
    )
  }

  @MainActor
  package static func getBillingPaymentAttempts(
    orgId: String?,
    initialPage: Int?,
    pageSize: Int?
  ) async throws -> ClerkPaginatedResponse<BillingPayment> {
    try await callInstance(
      .billing,
      BillingJSMethod.getPaymentAttempts,
      BillingQueryArgs(orgId: orgId, initialPage: initialPage, pageSize: pageSize),
      as: ClerkPaginatedResponse<BillingPayment>.self
    )
  }

  @MainActor
  package static func getBillingPaymentAttempt(
    id: String,
    orgId: String?,
    initialPage: Int?,
    pageSize: Int?
  ) async throws -> BillingPayment {
    try await callInstance(
      .billing,
      BillingJSMethod.getPaymentAttempt,
      BillingQueryArgs(id: id, orgId: orgId, initialPage: initialPage, pageSize: pageSize),
      as: BillingPayment.self
    )
  }

  @MainActor
  package static func getBillingCreditBalance(orgId: String?) async throws -> BillingCreditBalance {
    try await callInstance(
      .billing,
      BillingJSMethod.getCreditBalance,
      BillingQueryArgs(orgId: orgId),
      as: BillingCreditBalance.self
    )
  }

  @MainActor
  package static func getBillingCreditHistory(orgId: String?) async throws -> ClerkPaginatedResponse<BillingCreditLedger> {
    try await callInstance(
      .billing,
      BillingJSMethod.getCreditHistory,
      BillingQueryArgs(orgId: orgId),
      as: ClerkPaginatedResponse<BillingCreditLedger>.self
    )
  }

  @MainActor
  package static func getUserPaymentMethods(
    initialPage: Int?,
    pageSize: Int?
  ) async throws -> ClerkPaginatedResponse<BillingPaymentMethod> {
    try await callInstance(
      .user,
      UserJSMethod.getPaymentMethods,
      OptionalPageArgs(initialPage: initialPage, pageSize: pageSize),
      as: ClerkPaginatedResponse<BillingPaymentMethod>.self
    )
  }

  @MainActor
  package static func prepareSignInPasskeyFirstFactor() async throws {
    try await callInstance(
      .signIn,
      SignInJSMethod.prepareFirstFactor,
      PasskeyFactorArgs(
        strategy: "passkey",
        redirectUrl: Clerk.shared.options.redirectConfig.redirectUrl
      )
    )
  }

  @MainActor
  package static func prepareSignInPasskeySecondFactor() async throws {
    try await callInstance(
      .signIn,
      SignInJSMethod.prepareSecondFactor,
      PasskeyFactorArgs(strategy: "passkey")
    )
  }

  @MainActor
  package static func attemptSignInPasskeyFirstFactor(credential: String) async throws {
    try await callInstance(
      .signIn,
      SignInJSMethod.attemptFirstFactor,
      PasskeyFactorArgs(strategy: "passkey", publicKeyCredential: credential)
    )
  }

  @MainActor
  package static func attemptSignInPasskeySecondFactor(credential: String) async throws {
    try await callInstance(
      .signIn,
      SignInJSMethod.attemptSecondFactor,
      PasskeyFactorArgs(strategy: "passkey", publicKeyCredential: credential)
    )
  }

  @MainActor
  package static func reloadSignIn(rotatingTokenNonce: String?) async throws {
    try await callInstance(
      .signIn,
      SignInJSMethod.reload,
      ReloadArgs(rotatingTokenNonce: rotatingTokenNonce)
    )
  }

  @MainActor
  package static func reloadSignUp(rotatingTokenNonce: String?) async throws {
    try await callInstance(
      .signUp,
      SignUpJSMethod.reload,
      ReloadArgs(rotatingTokenNonce: rotatingTokenNonce)
    )
  }

  @MainActor
  package static func requireEngineClient() async throws -> any ClerkEngineClient {
    guard let engine = await resolvedEngineClient() else {
      throw ClerkClientError(message: "Clerk JS engine is not available.")
    }
    return engine
  }

  @MainActor
  package static func requireEngineSignIn() throws -> SignIn {
    guard let signIn = shared.client?.signIn else {
      throw ClerkClientError(message: "Sign-in did not produce a client.")
    }
    return signIn
  }

  @MainActor
  package static func requireEngineSignUp() throws -> SignUp {
    guard let signUp = shared.client?.signUp else {
      throw ClerkClientError(message: "Sign-up did not produce a client.")
    }
    return signUp
  }

  @MainActor
  package static func requireEngineTransferResult() throws -> TransferFlowResult {
    if let signUp = shared.client?.signUp, signUp.status != .abandoned {
      return .signUp(signUp)
    }
    if let signIn = shared.client?.signIn {
      return .signIn(signIn)
    }
    throw ClerkClientError(message: "OAuth did not produce a client.")
  }

  @MainActor
  package static func installLinkedEngineFactoryIfAvailable() {
    guard makeEngineClient == nil else { return }
    guard !EnvironmentDetection.isRunningInTests else { return }
    guard let marker = NSClassFromString("ClerkEngineBootstrapMarker") as? NSObject.Type else {
      return
    }
    _ = marker.perform(NSSelectorFromString("installEngineFactory"))
  }
}
