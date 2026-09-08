@testable import ClerkKit
import ClerkSnapshots
import Foundation

@MainActor
final class RecordingEngineClient: ClerkEngineClient {
  var nativeAppleArguments: ClerkSnapshots.JSONValue?
  var nativeCompletionResult: TransferFlowResult?
  var nativeCompletionError: (any Error)?
  var nativeCompletionFlow: String?
  var nativeCompletionMetadata: ClerkSnapshots.JSONValue?
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
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: identifier,
        supportedFirstFactors: [
          Factor(strategy: .emailLink, emailAddressId: "idn_email", safeIdentifier: identifier),
        ]
      )
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

  var sentEmailLinkAddressId: String?
  var sentEmailLinkRedirect: String?
  var sentEmailLinkChallenge: String?
  var sentEmailLinkChallengeMethod: String?
  var sentSignUpEmailLinkRedirect: String?
  var sentSignUpEmailLinkChallenge: String?

  func sendEmailLink(
    emailAddressId: String?,
    redirectUrl: String,
    codeChallenge: String,
    codeChallengeMethod: String
  ) async throws {
    sentEmailLinkAddressId = emailAddressId
    sentEmailLinkRedirect = redirectUrl
    sentEmailLinkChallenge = codeChallenge
    sentEmailLinkChallengeMethod = codeChallengeMethod
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .unverified, strategy: .emailLink)
      )
    )
  }

  func sendSignUpEmailLink(
    redirectUrl: String,
    codeChallenge: String,
    codeChallengeMethod _: String
  ) async throws {
    sentSignUpEmailLinkRedirect = redirectUrl
    sentSignUpEmailLinkChallenge = codeChallenge
    publish(SignUp.mock)
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
    var session = Session.mock
    session.lastActiveOrganizationId = organizationId
    Clerk.shared.applyResponseClient(
      Client(
        id: "client_engine",
        sessions: [session],
        lastActiveSessionId: session.id,
        updatedAt: Date()
      )
    )
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

  var signInPublishedByIdToken: SignIn?
  var signUpWithIdTokenError: (any Error)?
  var signUpPublishedByIdToken = SignUp.mock
  var signInPublishedBySignUpIdToken: SignIn?
  var signedUpIdToken: String?
  var signedUpIdTokenStrategy: String?
  var signedUpFirstName: String?
  var signedUpLastName: String?

  func signInWithIdToken(strategy: String, token: String) async throws {
    signedInIdTokenStrategy = strategy
    signedInIdToken = token
    publish(
      signInPublishedByIdToken
        ?? SignIn(
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

  func signUpWithIdToken(strategy: String, token: String, firstName: String?, lastName: String?) async throws {
    if let signUpWithIdTokenError {
      throw signUpWithIdTokenError
    }
    signedUpIdTokenStrategy = strategy
    signedUpIdToken = token
    signedUpFirstName = firstName
    signedUpLastName = lastName
    if let signInPublishedBySignUpIdToken {
      publish(signInPublishedBySignUpIdToken)
    } else {
      publish(signUpPublishedByIdToken)
    }
  }

  var redirectStrategy: String?
  var startedEnterpriseSSOEmail: String?
  var startedEnterpriseSSORedirectUrl: String?
  var signUpRedirectStrategy: String?
  var signUpRedirectEmail: String?
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

  func startEnterpriseSSO(emailAddress: String, redirectUrl: String) async throws {
    startedEnterpriseSSOEmail = emailAddress
    startedEnterpriseSSORedirectUrl = redirectUrl
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: emailAddress,
        firstFactorVerification: Verification(
          status: .unverified,
          strategy: .enterpriseSSO,
          externalVerificationRedirectUrl: "https://sso.example.com"
        )
      )
    )
  }

  func authenticateSignUpWithRedirect(strategy: String, redirectUrl _: String, emailAddress: String?) async throws {
    signUpRedirectStrategy = strategy
    signUpRedirectEmail = emailAddress
    publish(SignUp.mock)
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
  var updatedUnsafeMetadata: JSON?
  var updatedPasswordCurrent: String?
  var updatedPasswordNew: String?
  var updatedPasswordSignOutOfOtherSessions: Bool?
  var createdEmail: String?
  var createdPhone: String?
  var verifiedTotpCode: String?
  var deletedUser = false

  var reloadedUser = false
  var updatedMetadata: JSON?
  var createdBackupCodes = false
  var disabledTOTP = false
  var createdExternalAccountStrategy: String?
  var createdExternalAccountRedirectUrl: String?
  var createdExternalAccountScopes: [String]?
  var createdExternalAccountPrompt: String?
  var createdExternalAccountToken: String?
  var createdPasskey = false
  var createdOrganizationName: String?
  var createdOrganizationSlug: String?
  var fetchedOrganizationId: String?
  var organizationMethodId: String?
  var organizationMethodName: String?
  var organizationMethodArgs: Data?
  var instanceRoot: String?
  var instanceMethod: String?
  var instanceArgs: Data?
  var allInstanceMethods: [String] = []
  var instanceMethodErrors: [String: any Error] = [:]
  var reloadedNonce: String?
  var signInOnReload = SignIn.mock
  var signUpOnReload = SignUp.mock
  var userChildPick: String?
  var userChildId: String?
  var userChildMethod: String?
  var fetchedInvitationPage: Int?
  var fetchedInvitationPageSize: Int?
  var fetchedInvitationStatus: [String]?
  var fetchedMembershipPage: Int?
  var fetchedMembershipPageSize: Int?
  var fetchedSuggestionPage: Int?
  var fetchedSuggestionPageSize: Int?
  var fetchedSuggestionStatus: [String]?
  var fetchedSessions = false
  var leftOrganizationId: String?
  var fetchedCreationDefaults = false

  var transferredToSignUpMetadata: JSON?
  var transferredToSignIn = false

  func transferToSignUp(unsafeMetadata: JSON?) async throws {
    transferredToSignUpMetadata = unsafeMetadata
    publish(SignUp.mock)
  }

  func transferToSignIn() async throws {
    transferredToSignIn = true
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: "user@example.com"
      )
    )
  }

  var sessionVerificationLevel: String?
  var sessionFirstFactorStrategy: String?
  var sessionFirstFactorEmailAddressId: String?
  var sessionFirstFactorPhoneNumberId: String?
  var sessionFirstFactorEnterpriseConnectionId: String?
  var sessionFirstFactorRedirectUrl: String?
  var sessionFirstFactorCode: String?
  var sessionFirstFactorPassword: String?
  var sessionSecondFactorStrategy: String?
  var sessionSecondFactorPhoneNumberId: String?
  var sessionSecondFactorCode: String?
  var sessionSecondFactorPublicKeyCredential: String?
  var verifiedSessionWithPasskey = false

  func startSessionVerification(level: String) async throws -> SessionVerification {
    sessionVerificationLevel = level
    return .mockNeedsFirstFactor
  }

  func prepareSessionFirstFactor(
    strategy: String,
    emailAddressId: String?,
    phoneNumberId: String?,
    enterpriseConnectionId: String?,
    redirectUrl: String?
  ) async throws -> SessionVerification {
    sessionFirstFactorStrategy = strategy
    sessionFirstFactorEmailAddressId = emailAddressId
    sessionFirstFactorPhoneNumberId = phoneNumberId
    sessionFirstFactorEnterpriseConnectionId = enterpriseConnectionId
    sessionFirstFactorRedirectUrl = redirectUrl
    return .mockNeedsFirstFactor
  }

  func attemptSessionFirstFactor(
    strategy: String,
    code: String?,
    password: String?,
    publicKeyCredential _: String?
  ) async throws -> SessionVerification {
    sessionFirstFactorStrategy = strategy
    sessionFirstFactorCode = code
    sessionFirstFactorPassword = password
    return .mockComplete
  }

  func prepareSessionSecondFactor(strategy: String, phoneNumberId: String?) async throws -> SessionVerification {
    sessionSecondFactorStrategy = strategy
    sessionSecondFactorPhoneNumberId = phoneNumberId
    return .mockNeedsSecondFactor
  }

  func attemptSessionSecondFactor(
    strategy: String,
    code: String?,
    publicKeyCredential: String?
  ) async throws -> SessionVerification {
    sessionSecondFactorStrategy = strategy
    sessionSecondFactorCode = code
    sessionSecondFactorPublicKeyCredential = publicKeyCredential
    return .mockComplete
  }

  func verifySessionWithPasskey() async throws -> SessionVerification {
    verifiedSessionWithPasskey = true
    return .mockComplete
  }

  var lastJSReceiver: ClerkJSReceiver?
  var lastJSMethod: String?

  var currentUser: User {
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
