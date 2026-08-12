@testable import ClerkKit
@testable import ClerkKitUI
import LocalAuthentication
import Testing

@MainActor
struct AuthNavigationTests {
  @Test
  func trustedDeviceEnrollmentPrecedesPendingSessionTasks() {
    #expect(AuthView.postAuthStepOrder == [
      .trustedDeviceEnrollment,
      .sessionTasks,
      .complete,
    ])
  }

  @Test
  func routesTheFirstPendingSessionTaskWithItsExactToken() {
    let navigation = AuthNavigation()
    let session = session(pendingTasks: [.setupMfa, .resetPassword])
    let token = presentationToken(sessionId: session.id)

    #expect(navigation.routeToSessionTaskStart(session: session, token: token))
    #expect(navigation.path == [
      .sessionTaskStart(task: .setupMfa, token: token),
    ])
    #expect(navigation.presentedAuthFlowToken == token)
  }

  @Test
  func backendTaskChangesDoNotDismissThePresentedScreen() {
    let navigation = AuthNavigation()
    var session = session(pendingTasks: [.setupMfa])
    let token = presentationToken(sessionId: session.id)

    #expect(navigation.routeToSessionTaskStart(session: session, token: token))
    #expect(navigation.appendPostAuthDestination(.backupCodes(
      backupCodes: ["backup-code"],
      mfaType: .authenticatorApp,
      token: token
    )))
    let presentedPath = navigation.path

    session.status = .active
    session.tasks = []

    #expect(navigation.routeToSessionTaskStart(session: session, token: token))
    #expect(navigation.path == presentedPath)
    #expect(navigation.presentedAuthFlowToken == token)
  }

  @Test
  func aNewPresentationTokenReplacesOnlyThePostAuthSuffix() {
    let navigation = AuthNavigation()
    var sessionA = session(pendingTasks: [.setupMfa])
    sessionA.id = "session-a"
    var sessionB = session(pendingTasks: [.chooseOrganization])
    sessionB.id = "session-b"
    let tokenA = presentationToken(sessionId: sessionA.id)
    let tokenB = presentationToken(sessionId: sessionB.id)
    navigation.path = [.signUpCompleteProfile]

    #expect(navigation.routeToSessionTaskStart(session: sessionA, token: tokenA))
    #expect(navigation.appendPostAuthDestination(.taskMfaSmsChooseNumber(token: tokenA)))
    #expect(navigation.routeToSessionTaskStart(session: sessionB, token: tokenB))

    #expect(navigation.path == [
      .signUpCompleteProfile,
      .sessionTaskStart(task: .chooseOrganization, token: tokenB),
    ])
  }

  @Test
  func sequentialPresentationsForTheSameWorkRemainPushed() {
    let navigation = AuthNavigation()
    let session = session(pendingTasks: [.setupMfa])
    let work = AuthFlowWork(
      ownerId: UUID(),
      id: UUID(),
      sessionId: session.id
    )
    let enrollmentToken = presentationToken(
      work: work,
      kind: .trustedDeviceEnrollment
    )
    let taskToken = presentationToken(work: work)
    let biometry = TrustedDeviceBiometryDisplayName(biometryType: .faceID)

    navigation.routeToTrustedDeviceEnrollment(
      token: enrollmentToken,
      biometryDisplayName: biometry
    )
    navigation.synchronizePostAuthPath(with: work)
    #expect(navigation.routeToSessionTaskStart(
      session: session,
      token: taskToken
    ))

    #expect(navigation.path == [
      .trustedDeviceEnrollment(
        biometryDisplayName: biometry,
        token: enrollmentToken
      ),
      .sessionTaskStart(task: .setupMfa, token: taskToken),
    ])
  }

  @Test
  func staleScreenCannotAppendIntoAReplacementPresentation() {
    let navigation = AuthNavigation()
    let session = session(pendingTasks: [.setupMfa])
    let staleToken = presentationToken(sessionId: session.id)
    let currentToken = presentationToken(sessionId: session.id)

    #expect(navigation.routeToSessionTaskStart(
      session: session,
      token: currentToken
    ))

    #expect(navigation.appendPostAuthDestination(
      .taskVerifyTotp(token: staleToken)
    ) == false)
    #expect(navigation.path == [
      .sessionTaskStart(task: .setupMfa, token: currentToken),
    ])
  }

  @Test
  func trustedDeviceEnrollmentUsesItsExactPresentationToken() {
    let navigation = AuthNavigation()
    let token = presentationToken(
      sessionId: "session-a",
      kind: .trustedDeviceEnrollment
    )
    let biometry = TrustedDeviceBiometryDisplayName(biometryType: .faceID)
    navigation.path = [.signUpCompleteProfile]

    navigation.routeToTrustedDeviceEnrollment(
      token: token,
      biometryDisplayName: biometry
    )
    navigation.routeToTrustedDeviceEnrollment(
      token: token,
      biometryDisplayName: biometry
    )

    #expect(navigation.path == [
      .signUpCompleteProfile,
      .trustedDeviceEnrollment(
        biometryDisplayName: biometry,
        token: token
      ),
    ])
  }

  @Test
  func awaitingWorkClearsOnlyThePostAuthSuffix() {
    let navigation = AuthNavigation()
    let token = presentationToken(sessionId: "session-a")
    navigation.path = [
      .signUpCompleteProfile,
      .sessionTaskStart(task: .setupMfa, token: token),
      .taskMfaSmsChooseNumber(token: token),
    ]

    navigation.synchronizePostAuthPath(with: nil)

    #expect(navigation.path == [.signUpCompleteProfile])
    #expect(navigation.presentedAuthFlowToken == nil)
  }

  @Test
  func resetForNewAuthFlowClearsTheEntirePath() {
    let navigation = AuthNavigation()
    let token = presentationToken(
      sessionId: "session-a",
      kind: .trustedDeviceEnrollment
    )
    navigation.path = [
      .signUpCompleteProfile,
      .trustedDeviceEnrollment(
        biometryDisplayName: .init(biometryType: .touchID),
        token: token
      ),
    ]

    navigation.resetForNewAuthFlow()

    #expect(navigation.path.isEmpty)
  }

  @Test
  func signInNeedsNewPasswordRoutesWithoutAnAuthFlowToken() {
    let navigation = AuthNavigation()
    let signIn = SignIn(id: "sign_in_123", status: .needsNewPassword)

    navigation.setToStepForStatus(signIn: signIn)

    #expect(navigation.path == [.signInSetNewPassword(token: nil)])
  }

  @Test
  func signUpEmailLinkVerificationRunsBeforeCollectingMissingFields() {
    let navigation = AuthNavigation()
    let signUp = signUp(
      missingFields: [.password],
      unverifiedFields: [.emailAddress],
      verifications: ["email_address": Verification(status: .unverified, strategy: .emailLink)]
    )

    navigation.setToStepForStatus(signUp: signUp)

    #expect(navigation.path == [.signUpEmailLink])
  }

  @Test
  func signUpEmailCodeVerificationRunsBeforeCollectingMissingFields() {
    let navigation = AuthNavigation()
    let signUp = signUp(
      missingFields: [.password],
      unverifiedFields: [.emailAddress],
      verifications: ["email_address": Verification(status: .unverified, strategy: .emailCode)]
    )

    navigation.setToStepForStatus(signUp: signUp)

    #expect(navigation.path == [.signUpCode(.email("test@example.com"))])
  }

  @Test
  func signUpLegalAcceptedMissingRequirementRoutesToCompleteProfile() {
    let navigation = AuthNavigation()
    let signUp = signUp(
      missingFields: [.legalAccepted],
      unverifiedFields: [],
      verifications: [:]
    )

    navigation.setToStepForStatus(signUp: signUp)

    #expect(navigation.path == [.signUpCompleteProfile])
  }

  @Test
  func signUpUsernameRoutesBeforeCompleteProfile() {
    let navigation = AuthNavigation()
    let signUp = signUp(
      missingFields: [.firstName, .legalAccepted, .username],
      unverifiedFields: [],
      verifications: [:]
    )

    navigation.setToStepForStatus(signUp: signUp)

    #expect(navigation.path == [.signUpCollectField(.username)])
  }

  private func session(pendingTasks: [Session.Task]) -> Session {
    var session = Session.mock
    session.status = .pending
    session.tasks = pendingTasks
    return session
  }

  private func presentationToken(
    sessionId: String,
    kind: AuthFlowRegistration.PostAuthPresentation = .sessionTasks
  ) -> AuthFlowPresentationToken {
    presentationToken(
      work: AuthFlowWork(
        ownerId: UUID(),
        id: UUID(),
        sessionId: sessionId
      ),
      kind: kind
    )
  }

  private func presentationToken(
    work: AuthFlowWork,
    kind: AuthFlowRegistration.PostAuthPresentation = .sessionTasks
  ) -> AuthFlowPresentationToken {
    AuthFlowPresentationToken(
      work: work,
      id: UUID(),
      kind: kind
    )
  }

  private func signUp(
    missingFields: [SignUp.Field],
    unverifiedFields: [SignUp.Field],
    verifications: [String: Verification?]
  ) -> SignUp {
    SignUp(
      id: "sign_up_123",
      status: .missingRequirements,
      requiredFields: [.emailAddress, .password],
      optionalFields: [],
      missingFields: missingFields,
      unverifiedFields: unverifiedFields,
      verifications: verifications,
      emailAddress: "test@example.com",
      passwordEnabled: false,
      abandonAt: .distantFuture
    )
  }
}
