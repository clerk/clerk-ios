@testable import ClerkKit
@testable import ClerkKitUI
import LocalAuthentication
import Testing

@MainActor
final class AuthNavigationTests {
  private var owners: [Clerk] = []
  @Test
  func biometricCredentialEnrollmentPrecedesPendingSessionTasks() {
    #expect(AuthView.postAuthStepOrder == [
      .biometricCredentialEnrollment,
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
  func backendTaskChangesDoNotDismissThePresentedScreen() throws {
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

    var state = try session.state.encode().object()
    state["status"] = .string("active")
    state["tasks"] = .array([])
    state["currentTask"] = .null
    setTestResourceState(session, encoded: .object(state), path: [], value: .object(state))

    #expect(navigation.routeToSessionTaskStart(session: session, token: token))
    #expect(navigation.path == presentedPath)
    #expect(navigation.presentedAuthFlowToken == token)
  }

  @Test
  func aNewPresentationTokenReplacesOnlyThePostAuthSuffix() {
    let navigation = AuthNavigation()
    let sessionA = session(pendingTasks: [.setupMfa], id: "session-a")
    let sessionB = session(pendingTasks: [.chooseOrganization], id: "session-b")
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
      kind: .biometricCredentialEnrollment
    )
    let taskToken = presentationToken(work: work)
    let biometry = BiometryDisplayName(biometryType: .faceID)

    navigation.routeToBiometricCredentialEnrollment(
      token: enrollmentToken,
      biometryDisplayName: biometry
    )
    navigation.synchronizePostAuthPath(with: work)
    #expect(navigation.routeToSessionTaskStart(
      session: session,
      token: taskToken
    ))

    #expect(navigation.path == [
      .biometricCredentialEnrollment(
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
  func biometricCredentialEnrollmentUsesItsExactPresentationToken() {
    let navigation = AuthNavigation()
    let token = presentationToken(
      sessionId: "session-a",
      kind: .biometricCredentialEnrollment
    )
    let biometry = BiometryDisplayName(biometryType: .faceID)
    navigation.path = [.signUpCompleteProfile]

    navigation.routeToBiometricCredentialEnrollment(
      token: token,
      biometryDisplayName: biometry
    )
    navigation.routeToBiometricCredentialEnrollment(
      token: token,
      biometryDisplayName: biometry
    )

    #expect(navigation.path == [
      .signUpCompleteProfile,
      .biometricCredentialEnrollment(
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
      kind: .biometricCredentialEnrollment
    )
    navigation.path = [
      .signUpCompleteProfile,
      .biometricCredentialEnrollment(
        biometryDisplayName: .init(biometryType: .touchID),
        token: token
      ),
    ]

    navigation.resetForNewAuthFlow()

    #expect(navigation.path.isEmpty)
  }

  @Test
  func signInNeedsNewPasswordRoutesWithoutAnAuthFlowToken() throws {
    let navigation = AuthNavigation()
    let clerk = Clerk.preview(.signedOut)
    let signIn = clerk.signIn
    try setTestResourceState(signIn, encoded: signIn.state.encode(), path: ["status"], value: .string("needs_new_password"))

    navigation.setToStepForStatus(signIn: signIn)

    #expect(navigation.path == [.signInSetNewPassword(token: nil)])
  }

  @Test
  func signUpEmailLinkVerificationRunsBeforeCollectingMissingFields() {
    let navigation = AuthNavigation()
    let signUp = signUp(
      missingFields: [.password],
      unverifiedFields: [.emailAddress],
      emailStrategy: "email_link"
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
      emailStrategy: "email_code"
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
      emailStrategy: nil
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
      emailStrategy: nil
    )

    navigation.setToStepForStatus(signUp: signUp)

    #expect(navigation.path == [.signUpCollectField(.username)])
  }

  private func session(pendingTasks: [SessionTaskKey], id: String = "sess_123") -> Session {
    let clerk = Clerk.preview()
    owners.append(clerk)
    let session = clerk.session!
    var state = try! session.state.encode().object()
    state["id"] = .string(id)
    state["status"] = .string("pending")
    state["tasks"] = .array(pendingTasks.map { .object(["key": .string($0.rawValue)]) })
    state["currentTask"] = pendingTasks.first.map { .object(["key": .string($0.rawValue)]) } ?? .null
    setTestResourceState(session, encoded: .object(state), path: [], value: .object(state))
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
    missingFields: [SignUpField],
    unverifiedFields: [SignUpField],
    emailStrategy: String?
  ) -> SignUp {
    let clerk = Clerk.preview(.signedOut)
    owners.append(clerk)
    let signUp = clerk.signUp
    var state = try! signUp.state.encode().object()
    state["id"] = .string("sign_up_123")
    state["status"] = .string("missing_requirements")
    state["requiredFields"] = .array([.string("email_address"), .string("password")])
    state["missingFields"] = .array(missingFields.map { .string($0.rawValue) })
    state["unverifiedFields"] = .array(unverifiedFields.map { .string($0.rawValue) })
    state["emailAddress"] = .string("test@example.com")
    setTestResourceState(signUp, encoded: .object(state), path: [], value: .object(state))
    let verification = signUp.verifications.emailAddress
    setTestResourceState(verification, encoded: try! verification.state.encode(), path: ["strategy"], value: emailStrategy.map(JSONValue.string) ?? .null)
    return signUp
  }
}
