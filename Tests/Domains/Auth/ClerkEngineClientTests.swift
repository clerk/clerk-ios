@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkEngineClientTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func signInWithEmailCodeUsesEngineAndSkipsKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)

    let signIn = try await Clerk.shared.auth.signInWithEmailCode(emailAddress: "user@example.com")

    #expect(engine.signedInEmail == "user@example.com")
    #expect(signIn.id == "sia_engine")
    #expect(kitCalls.createCount == 0)
  }

  @Test
  func sendAndVerifyEmailCodeUseEngine() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)

    _ = try await Clerk.shared.auth.signInWithEmailCode(emailAddress: "user@example.com")
    let current = try #require(Clerk.shared.auth.currentSignIn)
    let prepared = try await current.sendEmailCode(emailAddressId: "idn_email")
    #expect(engine.sentEmailAddressId == "idn_email")
    #expect(prepared.firstFactorVerification?.strategy == .emailCode)

    let verified = try await prepared.verifyCode("424242")
    #expect(engine.verifiedCode == "424242")
    #expect(verified.status == .complete)
    #expect(verified.createdSessionId == "sess_engine")
    #expect(kitCalls.prepareCount == 0)
    #expect(kitCalls.attemptCount == 0)
  }

  @Test
  func passwordPhoneSetActiveAndGetTokenUseEngine() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)
    installFailingSessionService(kitCalls)

    let password = try await Clerk.shared.auth.signInWithPassword(
      identifier: "user@example.com",
      password: "hunter2"
    )
    #expect(engine.passwordIdentifier == "user@example.com")
    #expect(engine.password == "hunter2")
    #expect(password.status == .complete)

    _ = try await Clerk.shared.auth.signInWithPhoneCode(phoneNumber: "+15555550100")
    let phoneSignIn = try #require(Clerk.shared.auth.currentSignIn)
    _ = try await phoneSignIn.sendPhoneCode(phoneNumberId: "idn_phone")
    let verifiedPhone = try await phoneSignIn.verifyCode("424242")
    #expect(engine.signedInPhone == "+15555550100")
    #expect(engine.sentPhoneNumberId == "idn_phone")
    #expect(engine.verifiedPhoneCode == "424242")
    #expect(verifiedPhone.status == .complete)

    try await Clerk.shared.auth.setActive(sessionId: "sess_engine", organizationId: "org_1")
    #expect(engine.activeSessionId == "sess_engine")
    #expect(engine.activeOrganizationId == "org_1")

    let token = try await Clerk.shared.auth.getToken()
    #expect(token == "jwt_engine")

    try await Clerk.shared.auth.signOut()
    #expect(engine.signedOut)
    #expect(kitCalls.createCount == 0)
    #expect(kitCalls.setActiveCount == 0)
    #expect(kitCalls.fetchTokenCount == 0)
    #expect(kitCalls.signOutCount == 0)
  }

  @Test
  func signUpEmailCodeUsesEngine() async throws {
    let engine = RecordingEngineClient()
    Clerk.engineClient = engine

    let created = try await Clerk.shared.auth.signUp(emailAddress: "user@example.com")
    #expect(engine.signedUpEmail == "user@example.com")
    #expect(created.emailAddress == "user@example.com")

    _ = try await created.sendEmailCode()
    #expect(engine.sentSignUpEmailCode)

    let verified = try await created.verifyEmailCode("424242")
    #expect(engine.verifiedSignUpEmailCode == "424242")
    #expect(verified.status == .complete)
    #expect(verified.createdSessionId == "sess_engine")
  }

  @Test
  func oauthPasskeyMfaResetAndSignUpUpdateUseEngine() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)
    installFailingSignUpService(kitCalls)

    let oauth = try await Clerk.shared.auth.signInWithOAuth(provider: .google)
    #expect(engine.redirectStrategy == "oauth_google")
    if case .signIn(let signIn) = oauth {
      #expect(signIn.id == "sia_engine")
    } else {
      Issue.record("Expected a sign-in transfer result")
    }

    engine.publish(
      SignIn(id: "sia_engine", status: .needsFirstFactor, identifier: "user@example.com")
    )
    let current = try #require(Clerk.shared.auth.currentSignIn)
    _ = try await current.sendResetPasswordEmailCode(emailAddressId: "idn_email")
    _ = try await current.sendResetPasswordPhoneCode(phoneNumberId: "idn_phone")
    engine.publish(
      SignIn(
        id: "sia_engine",
        status: .needsNewPassword,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .verified, strategy: .resetPasswordEmailCode)
      )
    )
    let resetSignIn = try #require(Clerk.shared.auth.currentSignIn)
    let verifiedReset = try await resetSignIn.verifyCode("424242")
    #expect(engine.resetEmailAddressId == "idn_email")
    #expect(engine.resetPhoneNumberId == "idn_phone")
    #expect(engine.verifiedResetCode == "424242")
    #expect(verifiedReset.status == .needsNewPassword)

    let reset = try await current.resetPassword(newPassword: "new-pass", signOutOfOtherSessions: true)
    #expect(engine.resetPassword == "new-pass")
    #expect(engine.resetSignOutOfOtherSessions == true)
    #expect(reset.status == .complete)

    engine.publish(
      SignIn(id: "sia_engine", status: .needsSecondFactor, identifier: "user@example.com")
    )
    let mfaSignIn = try #require(Clerk.shared.auth.currentSignIn)
    _ = try await mfaSignIn.sendMfaEmailCode(emailAddressId: "idn_mfa_email")
    _ = try await mfaSignIn.sendMfaPhoneCode(phoneNumberId: "idn_mfa_phone")
    let mfa = try await mfaSignIn.verifyMfaCode("424242", type: .totp)
    #expect(engine.sentMfaEmailAddressId == "idn_mfa_email")
    #expect(engine.sentMfaPhoneNumberId == "idn_mfa_phone")
    #expect(engine.verifiedMfaCode == "424242")
    #expect(engine.verifiedMfaType == .totp)
    #expect(mfa.status == .complete)

    let passkey = try await Clerk.shared.auth.signInWithPasskey()
    #expect(engine.authenticatedPasskey)
    #expect(passkey.status == .complete)

    engine.publish(SignUp.mock)
    let signUp = try #require(Clerk.shared.auth.currentSignUp)
    let updated = try await signUp.update(firstName: "Ada", lastName: "Lovelace")
    #expect(engine.updatedSignUpFirstName == "Ada")
    #expect(engine.updatedSignUpLastName == "Lovelace")
    #expect(updated.firstName == "Ada")
    #expect(kitCalls.createCount == 0)
    #expect(kitCalls.prepareCount == 0)
    #expect(kitCalls.attemptCount == 0)
    #expect(kitCalls.prepareSecondCount == 0)
    #expect(kitCalls.attemptSecondCount == 0)
    #expect(kitCalls.resetPasswordCount == 0)
    #expect(kitCalls.signUpUpdateCount == 0)
  }

  @Test
  func ticketAndIdTokenUseEngine() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)
    installFailingSignUpService(kitCalls)

    let ticket = try await Clerk.shared.auth.signInWithTicket("tkt_engine")
    #expect(engine.signedInTicket == "tkt_engine")
    #expect(ticket.status == .complete)

    let idToken = try await Clerk.shared.auth.signInWithIdToken("apple_token", provider: .apple)
    #expect(engine.signedInIdToken == "apple_token")
    #expect(engine.signedInIdTokenStrategy == "oauth_token_apple")
    if case .signIn(let signIn) = idToken {
      #expect(signIn.status == .complete)
    } else {
      Issue.record("Expected a sign-in transfer result")
    }

    let signUp = try await Clerk.shared.auth.signUpWithTicket("tkt_signup")
    #expect(engine.signedUpTicket == "tkt_signup")
    #expect(signUp.id == SignUp.mock.id)
    #expect(kitCalls.createCount == 0)
  }

  @Test
  func refreshSkipsKitFAPIWhenEngineIsRegistered() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    Clerk.shared.environment = .mock
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: MockClientService {
        kitCalls.clientRefreshCount += 1
        throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
      },
      environmentService: MockEnvironmentService {
        kitCalls.environmentRefreshCount += 1
        throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
      }
    )

    let environment = try await Clerk.shared.refreshEnvironment()
    let client = try await Clerk.shared.refreshClient()

    #expect(environment.displayConfig.applicationName == Clerk.Environment.mock.displayConfig.applicationName)
    #expect(client == Clerk.shared.client)
    #expect(kitCalls.environmentRefreshCount == 0)
    #expect(kitCalls.clientRefreshCount == 0)
  }

  @Test
  func userMutationsUseEngineAndSkipKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingUserService(kitCalls)
    engine.publish(User.mock)
    let user = try #require(Clerk.shared.user)

    let updated = try await user.update(.init(firstName: "Ada", lastName: "Lovelace"))
    #expect(engine.updatedUsername == nil)
    #expect(engine.updatedFirstName == "Ada")
    #expect(engine.updatedLastName == "Lovelace")
    #expect(updated.firstName == "Ada")
    #expect(updated.lastName == "Lovelace")

    _ = try await user.updatePassword(
      .init(currentPassword: "old-pass", newPassword: "new-pass", signOutOfOtherSessions: true)
    )
    #expect(engine.updatedPasswordCurrent == "old-pass")
    #expect(engine.updatedPasswordNew == "new-pass")
    #expect(engine.updatedPasswordSignOutOfOtherSessions == true)

    let email = try await user.createEmailAddress("added@example.com")
    #expect(engine.createdEmail == "added@example.com")
    #expect(email.emailAddress == "added@example.com")

    let phone = try await user.createPhoneNumber("+15555550999")
    #expect(engine.createdPhone == "+15555550999")
    #expect(phone.phoneNumber == "+15555550999")

    let totp = try await user.createTOTP()
    #expect(totp.id == "totp_engine")
    #expect(totp.verified == false)

    let verified = try await user.verifyTOTP(code: "424242")
    #expect(engine.verifiedTotpCode == "424242")
    #expect(verified.id == "totp_engine")

    let deleted = try await user.delete()
    #expect(engine.deletedUser)
    #expect(deleted.deleted == true)
    #expect(kitCalls.userServiceCount == 0)
  }

  @Test
  func configureDoesNotInstallEngineInTests() async {
    #expect(Clerk.makeEngineClient == nil)
    #expect(await Clerk.resolvedEngineClient() == nil)
  }

  @Test
  func resolvedEngineClientCreatesOnceFromFactory() async {
    var creations = 0
    Clerk.makeEngineClient = { _ in
      creations += 1
      return RecordingEngineClient()
    }

    let first = await Clerk.resolvedEngineClient()
    let second = await Clerk.resolvedEngineClient()

    #expect(creations == 1)
    #expect(first != nil)
    #expect(second != nil)
  }
}

@MainActor
private final class RecordingEngineClient: ClerkEngineClient {
  var signedInIdentifier: String?
  var signedInEmail: String?
  var signedInPhone: String?
  var passwordIdentifier: String?
  var password: String?
  var sentEmailAddressId: String?
  var sentPhoneNumberId: String?
  var verifiedCode: String?
  var verifiedPhoneCode: String?
  var activeSessionId: String?
  var activeOrganizationId: String?
  var signedOut = false

  func signIn(identifier: String) async throws {
    signedInIdentifier = identifier
    publish(
      SignIn(id: "sia_engine", status: .needsFirstFactor, identifier: identifier)
    )
  }

  func signInWithEmailCode(emailAddress: String) async throws {
    signedInEmail = emailAddress
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: emailAddress,
        firstFactorVerification: Verification(status: .unverified, strategy: .emailCode)
      )
    )
  }

  func signInWithPhoneCode(phoneNumber: String) async throws {
    signedInPhone = phoneNumber
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: phoneNumber,
        firstFactorVerification: Verification(status: .unverified, strategy: .phoneCode)
      )
    )
  }

  func signInWithPassword(identifier: String, password: String) async throws {
    passwordIdentifier = identifier
    self.password = password
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        identifier: identifier,
        createdSessionId: "sess_engine"
      )
    )
  }

  func sendEmailCode(emailAddressId: String?) async throws {
    sentEmailAddressId = emailAddressId
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .unverified, strategy: .emailCode)
      )
    )
  }

  func sendPhoneCode(phoneNumberId: String?) async throws {
    sentPhoneNumberId = phoneNumberId
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: "+15555550100",
        firstFactorVerification: Verification(status: .unverified, strategy: .phoneCode)
      )
    )
  }

  func verifyEmailCode(_ code: String) async throws {
    verifiedCode = code
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .verified, strategy: .emailCode),
        createdSessionId: "sess_engine"
      )
    )
  }

  func verifyPhoneCode(_ code: String) async throws {
    verifiedPhoneCode = code
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        identifier: "+15555550100",
        firstFactorVerification: Verification(status: .verified, strategy: .phoneCode),
        createdSessionId: "sess_engine"
      )
    )
  }

  func authenticateWithPassword(_ password: String) async throws {
    self.password = password
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        identifier: "user@example.com",
        createdSessionId: "sess_engine"
      )
    )
  }

  func setActive(sessionId: String, organizationId: String?) async throws {
    activeSessionId = sessionId
    activeOrganizationId = organizationId
  }

  func signOut(sessionId _: String?) async throws {
    signedOut = true
    Clerk.shared.applyResponseClient(
      Client(id: "client_engine", sessions: [], updatedAt: Date())
    )
  }

  func getToken(template _: String?, skipCache _: Bool) async throws -> String? {
    "jwt_engine"
  }

  var signedUpEmail: String?
  var sentSignUpEmailCode = false
  var verifiedSignUpEmailCode: String?

  func signUp(
    emailAddress: String?,
    password _: String?,
    firstName _: String?,
    lastName _: String?,
    username _: String?,
    phoneNumber _: String?,
    legalAccepted _: Bool?,
    transfer _: Bool
  ) async throws {
    signedUpEmail = emailAddress
    var signUp = SignUp.mock
    signUp.emailAddress = emailAddress
    signUp.status = .missingRequirements
    publish(signUp)
  }

  func sendSignUpEmailCode() async throws {
    sentSignUpEmailCode = true
    var signUp = SignUp.mock
    signUp.emailAddress = "user@example.com"
    publish(signUp)
  }

  func sendSignUpPhoneCode() async throws {
    let signUp = SignUp.mock
    publish(signUp)
  }

  func verifySignUpEmailCode(_ code: String) async throws {
    verifiedSignUpEmailCode = code
    var signUp = SignUp.mock
    signUp.status = .complete
    signUp.createdSessionId = "sess_engine"
    publish(signUp)
  }

  func verifySignUpPhoneCode(_: String) async throws {
    var signUp = SignUp.mock
    signUp.status = .complete
    signUp.createdSessionId = "sess_engine"
    publish(signUp)
  }

  var signedInTicket: String?
  var signedInIdToken: String?
  var signedInIdTokenStrategy: String?
  var signedUpTicket: String?

  func signInWithTicket(_ ticket: String) async throws {
    signedInTicket = ticket
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        createdSessionId: "sess_engine"
      )
    )
  }

  func signInWithIdToken(strategy: String, token: String) async throws {
    signedInIdTokenStrategy = strategy
    signedInIdToken = token
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        createdSessionId: "sess_engine"
      )
    )
  }

  func authenticateWithIdToken(strategy: String, token: String) async throws {
    signedInIdTokenStrategy = strategy
    signedInIdToken = token
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        createdSessionId: "sess_engine"
      )
    )
  }

  func signUpWithTicket(_ ticket: String) async throws {
    signedUpTicket = ticket
    publish(SignUp.mock)
  }

  func signUpWithIdToken(strategy _: String, token: String, firstName _: String?, lastName _: String?) async throws {
    signedInIdToken = token
    publish(SignUp.mock)
  }

  var redirectStrategy: String?
  var resetEmailAddressId: String?
  var resetPhoneNumberId: String?
  var verifiedResetCode: String?
  var resetPassword: String?
  var resetSignOutOfOtherSessions: Bool?
  var sentMfaEmailAddressId: String?
  var sentMfaPhoneNumberId: String?
  var verifiedMfaCode: String?
  var verifiedMfaType: SignIn.MfaType?
  var authenticatedPasskey = false
  var updatedSignUpFirstName: String?
  var updatedSignUpLastName: String?

  func authenticateWithRedirect(strategy: String, redirectUrl _: String, identifier _: String?) async throws {
    redirectStrategy = strategy
    publish(
      SignIn(id: "sia_engine", status: .needsFirstFactor, identifier: "user@example.com")
    )
  }

  func createPasskeySignIn() async throws {
    publish(
      SignIn(id: "sia_engine", status: .needsFirstFactor, identifier: nil)
    )
  }

  func authenticateWithPasskey(autofill _: Bool) async throws {
    authenticatedPasskey = true
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        createdSessionId: "sess_engine"
      )
    )
  }

  func sendMfaPhoneCode(phoneNumberId: String?) async throws {
    sentMfaPhoneNumberId = phoneNumberId
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsSecondFactor,
        identifier: "user@example.com",
        secondFactorVerification: Verification(status: .unverified, strategy: .phoneCode)
      )
    )
  }

  func sendMfaEmailCode(emailAddressId: String?) async throws {
    sentMfaEmailAddressId = emailAddressId
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsSecondFactor,
        identifier: "user@example.com",
        secondFactorVerification: Verification(status: .unverified, strategy: .emailCode)
      )
    )
  }

  func verifyMfaCode(_ code: String, type: SignIn.MfaType) async throws {
    verifiedMfaCode = code
    verifiedMfaType = type
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        identifier: "user@example.com",
        createdSessionId: "sess_engine"
      )
    )
  }

  func sendResetPasswordEmailCode(emailAddressId: String?) async throws {
    resetEmailAddressId = emailAddressId
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .unverified, strategy: .resetPasswordEmailCode)
      )
    )
  }

  func sendResetPasswordPhoneCode(phoneNumberId: String?) async throws {
    resetPhoneNumberId = phoneNumberId
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .unverified, strategy: .resetPasswordPhoneCode)
      )
    )
  }

  func verifyResetPasswordCode(_ code: String, isEmail _: Bool) async throws {
    verifiedResetCode = code
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsNewPassword,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .verified, strategy: .resetPasswordEmailCode)
      )
    )
  }

  func resetPassword(password: String, signOutOfOtherSessions: Bool) async throws {
    resetPassword = password
    resetSignOutOfOtherSessions = signOutOfOtherSessions
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        identifier: "user@example.com",
        createdSessionId: "sess_engine"
      )
    )
  }

  func updateSignUp(
    emailAddress _: String?,
    password _: String?,
    firstName: String?,
    lastName: String?,
    username _: String?,
    phoneNumber _: String?,
    legalAccepted _: Bool?
  ) async throws {
    updatedSignUpFirstName = firstName
    updatedSignUpLastName = lastName
    var signUp = SignUp.mock
    signUp.firstName = firstName
    signUp.lastName = lastName
    publish(signUp)
  }

  var updatedUsername: String?
  var updatedFirstName: String?
  var updatedLastName: String?
  var updatedPrimaryEmailAddressId: String?
  var updatedPrimaryPhoneNumberId: String?
  var updatedPasswordCurrent: String?
  var updatedPasswordNew: String?
  var updatedPasswordSignOutOfOtherSessions: Bool?
  var createdEmail: String?
  var createdPhone: String?
  var verifiedTotpCode: String?
  var deletedUser = false

  func updateUser(
    username: String?,
    firstName: String?,
    lastName: String?,
    primaryEmailAddressId: String?,
    primaryPhoneNumberId: String?
  ) async throws {
    updatedUsername = username
    updatedFirstName = firstName
    updatedLastName = lastName
    updatedPrimaryEmailAddressId = primaryEmailAddressId
    updatedPrimaryPhoneNumberId = primaryPhoneNumberId
    var user = currentUser
    user.firstName = firstName ?? user.firstName
    user.lastName = lastName ?? user.lastName
    user.username = username ?? user.username
    user.primaryEmailAddressId = primaryEmailAddressId ?? user.primaryEmailAddressId
    user.primaryPhoneNumberId = primaryPhoneNumberId ?? user.primaryPhoneNumberId
    publish(user)
  }

  func updatePassword(currentPassword: String?, newPassword: String, signOutOfOtherSessions: Bool) async throws {
    updatedPasswordCurrent = currentPassword
    updatedPasswordNew = newPassword
    updatedPasswordSignOutOfOtherSessions = signOutOfOtherSessions
    publish(currentUser)
  }

  func createEmailAddress(_ emailAddress: String) async throws {
    createdEmail = emailAddress
    var user = currentUser
    user.emailAddresses.append(EmailAddress(id: "idn_added", emailAddress: emailAddress))
    publish(user)
  }

  func createPhoneNumber(_ phoneNumber: String) async throws {
    createdPhone = phoneNumber
    var user = currentUser
    user.phoneNumbers.append(
      PhoneNumber(
        id: "idn_phone_added",
        phoneNumber: phoneNumber,
        reservedForSecondFactor: false,
        defaultSecondFactor: false
      )
    )
    publish(user)
  }

  func createTOTP() async throws -> Data {
    Data(#"{"id":"totp_engine","verified":false,"created_at":0,"updated_at":0}"#.utf8)
  }

  func verifyTOTP(code: String) async throws -> Data {
    verifiedTotpCode = code
    return Data(#"{"id":"totp_engine","verified":true,"created_at":0,"updated_at":0}"#.utf8)
  }

  func deleteUser() async throws -> Data {
    deletedUser = true
    return Data(#"{"object":"user","id":"1","deleted":true}"#.utf8)
  }

  private var currentUser: User {
    Clerk.shared.user ?? .mock
  }

  func publish(_ signIn: SignIn) {
    Clerk.shared.applyResponseClient(
      Client(
        id: "client_engine",
        signIn: signIn,
        sessions: [],
        updatedAt: Date()
      )
    )
  }

  func publish(_ signUp: SignUp) {
    Clerk.shared.applyResponseClient(
      Client(
        id: "client_engine",
        signUp: signUp,
        sessions: [],
        updatedAt: Date()
      )
    )
  }

  func publish(_ user: User) {
    var session = Session.mock
    session.user = user
    Clerk.shared.applyResponseClient(
      Client(
        id: "client_engine",
        sessions: [session],
        lastActiveSessionId: session.id,
        updatedAt: Date()
      )
    )
  }
}

@MainActor
private final class KitCallCounter {
  var createCount = 0
  var prepareCount = 0
  var attemptCount = 0
  var setActiveCount = 0
  var fetchTokenCount = 0
  var signOutCount = 0
  var environmentRefreshCount = 0
  var clientRefreshCount = 0
  var prepareSecondCount = 0
  var attemptSecondCount = 0
  var resetPasswordCount = 0
  var signUpUpdateCount = 0
  var userServiceCount = 0
}

@MainActor
private func installFailingSignInService(_ counts: KitCallCounter) {
  let service = MockSignInService(
    create: { _ in
      counts.createCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    },
    prepareFirstFactor: { _, _ in
      counts.prepareCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    },
    attemptFirstFactor: { _, _ in
      counts.attemptCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    },
    prepareSecondFactor: { _, _ in
      counts.prepareSecondCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    },
    attemptSecondFactor: { _, _ in
      counts.attemptSecondCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    },
    resetPassword: { _, _ in
      counts.resetPasswordCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    }
  )
  Clerk.shared.dependencies = MockDependencyContainer(
    apiClient: createMockAPIClient(),
    signInService: service
  )
  try! (Clerk.shared.dependencies as! MockDependencyContainer)
    .configurationManager
    .configure(publishableKey: testPublishableKey, options: .init())
}

@MainActor
private func installFailingSessionService(_ counts: KitCallCounter) {
  let service = MockSessionService(
    signOut: { _ in
      counts.signOutCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    },
    setActive: { _, _ in
      counts.setActiveCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    },
    fetchToken: { _, _, _ in
      counts.fetchTokenCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    }
  )
  Clerk.shared.dependencies = MockDependencyContainer(
    apiClient: createMockAPIClient(),
    signInService: Clerk.shared.dependencies.signInService,
    sessionService: service
  )
  try! (Clerk.shared.dependencies as! MockDependencyContainer)
    .configurationManager
    .configure(publishableKey: testPublishableKey, options: .init())
}

@MainActor
private func installFailingSignUpService(_ counts: KitCallCounter) {
  let service = MockSignUpService(
    update: { _, _ in
      counts.signUpUpdateCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    }
  )
  Clerk.shared.dependencies = MockDependencyContainer(
    apiClient: createMockAPIClient(),
    signInService: Clerk.shared.dependencies.signInService,
    signUpService: service
  )
  try! (Clerk.shared.dependencies as! MockDependencyContainer)
    .configurationManager
    .configure(publishableKey: testPublishableKey, options: .init())
}

@MainActor
private func installFailingUserService(_ counts: KitCallCounter) {
  let fail: () -> ClerkClientError = {
    counts.userServiceCount += 1
    return ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
  }
  let service = MockUserService(
    update: { _ in throw fail() },
    createEmailAddress: { _ in throw fail() },
    createPhoneNumber: { _ in throw fail() },
    createTotp: { throw fail() },
    verifyTotp: { _ in throw fail() },
    updatePassword: { _ in throw fail() },
    delete: { throw fail() }
  )
  Clerk.shared.dependencies = MockDependencyContainer(
    apiClient: createMockAPIClient(),
    userService: service
  )
  try! (Clerk.shared.dependencies as! MockDependencyContainer)
    .configurationManager
    .configure(publishableKey: testPublishableKey, options: .init())
}
