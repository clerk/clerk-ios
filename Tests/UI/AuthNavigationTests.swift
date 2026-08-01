@testable import ClerkKit
@testable import ClerkKitUI
import LocalAuthentication
import Testing

@MainActor
struct AuthNavigationTests {
  @Test
  func handleSessionTaskCompletionRoutesToCurrentFirstPendingTask() {
    let navigation = AuthNavigation()
    let session = session(pendingTasks: [.setupMfa, .resetPassword])

    navigation.handleSessionTaskCompletion(session: session)

    #expect(navigation.path == [.sessionTaskStart(task: .setupMfa)])
    #expect(navigation.postAuthStepsComplete == false)
  }

  @Test
  func handleSessionTaskCompletionMarksPostAuthStepsCompleteWhenSessionHasNoPendingTasks() {
    let navigation = AuthNavigation()
    let session = session(pendingTasks: [])

    navigation.handleSessionTaskCompletion(session: session)

    #expect(navigation.path.isEmpty)
    #expect(navigation.postAuthStepsComplete)
  }

  @Test
  func routeToTrustedDeviceEnrollmentAppendsToAuthPathAndMarksOfferShown() {
    let navigation = AuthNavigation()
    let biometryDisplayName = TrustedDeviceBiometryDisplayName(biometryType: .faceID)
    navigation.path = [.signUpCompleteProfile]

    navigation.routeToTrustedDeviceEnrollment(
      biometryDisplayName: biometryDisplayName
    )

    #expect(navigation.path == [
      .signUpCompleteProfile,
      .trustedDeviceEnrollment(biometryDisplayName: biometryDisplayName),
    ])
    #expect(navigation.hasTrustedDeviceEnrollmentInPath)
    #expect(navigation.trustedDeviceEnrollmentWasOffered)
  }

  @Test
  func resetForNewAuthFlowClearsPathAndPostAuthFlags() {
    let navigation = AuthNavigation()
    let biometryDisplayName = TrustedDeviceBiometryDisplayName(biometryType: .faceID)
    navigation.path = [
      .trustedDeviceEnrollment(biometryDisplayName: biometryDisplayName),
    ]
    navigation.routeToTrustedDeviceEnrollment(
      biometryDisplayName: biometryDisplayName
    )
    navigation.markPostAuthStepsComplete()

    navigation.resetForNewAuthFlow()

    #expect(navigation.path.isEmpty)
    #expect(navigation.postAuthStepsComplete == false)
    #expect(navigation.trustedDeviceEnrollmentWasOffered == false)
  }

  @Test
  func routeToSessionTaskStartRoutesResetPasswordTaskOnce() {
    let navigation = AuthNavigation()
    let session = session(pendingTasks: [.resetPassword])

    let didRoute = navigation.routeToSessionTaskStartIfNeeded(session: session)
    let didRouteAgain = navigation.routeToSessionTaskStartIfNeeded(session: session)

    #expect(didRoute)
    #expect(didRouteAgain)
    #expect(navigation.path == [.sessionTaskStart(task: .resetPassword)])
  }

  @Test
  func routeToSessionTaskStartRoutesChooseOrganizationTask() {
    let navigation = AuthNavigation()
    let session = session(pendingTasks: [.chooseOrganization])

    let didRoute = navigation.routeToSessionTaskStartIfNeeded(session: session)

    #expect(didRoute)
    #expect(navigation.path == [.sessionTaskStart(task: .chooseOrganization)])
  }

  @Test
  func dismissibleAuthWaitsForItsCompletedSignInBeforeFinishing() {
    var session = Session.mock
    session.status = .active
    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = session.id

    let action = AuthView.existingSessionChangeAction(
      oldValue: nil,
      newValue: session,
      isDismissible: true,
      hasTrustedDeviceEnrollmentInPath: false,
      hasSessionTaskStartInPath: false,
      pendingAuthFlowCompletion: .signIn(signIn),
      isAuthFlowComplete: false
    )

    #expect(action == .wait)
  }

  @Test
  func dismissibleAuthFinishesForExternallyActivatedSession() {
    var session = Session.mock
    session.status = .active

    let action = AuthView.existingSessionChangeAction(
      oldValue: nil,
      newValue: session,
      isDismissible: true,
      hasTrustedDeviceEnrollmentInPath: false,
      hasSessionTaskStartInPath: false,
      pendingAuthFlowCompletion: nil,
      isAuthFlowComplete: true
    )

    #expect(action == .finishAuthFlow)
  }

  @Test
  func handleSessionTaskCompletionRoutesToChooseOrganizationWhenItIsNextPendingTask() {
    let navigation = AuthNavigation()
    let session = session(pendingTasks: [.chooseOrganization])

    navigation.handleSessionTaskCompletion(session: session)

    #expect(navigation.path == [.sessionTaskStart(task: .chooseOrganization)])
    #expect(navigation.postAuthStepsComplete == false)
  }

  @Test
  func signInNeedsNewPasswordRoutesToSetNewPassword() {
    let navigation = AuthNavigation()
    let signIn = SignIn(id: "sign_in_123", status: .needsNewPassword)

    navigation.setToStepForStatus(signIn: signIn)

    #expect(navigation.path == [.signInSetNewPassword])
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
  func signUpUsernameMissingRequirementRoutesToCollectUsernameBeforeCompleteProfile() {
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
    session.tasks = pendingTasks
    return session
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
