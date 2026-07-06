@testable import ClerkKit
@testable import ClerkKitUI
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
    navigation.path = [.signUpCompleteProfile]

    navigation.routeToTrustedDeviceEnrollment()

    #expect(navigation.path == [.signUpCompleteProfile, .trustedDeviceEnrollment])
    #expect(navigation.hasTrustedDeviceEnrollmentInPath)
    #expect(navigation.trustedDeviceEnrollmentWasOffered)
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
  func handleSessionTaskCompletionRoutesToChooseOrganizationWhenItIsNextPendingTask() {
    let navigation = AuthNavigation()
    let session = session(pendingTasks: [.chooseOrganization])

    navigation.handleSessionTaskCompletion(session: session)

    #expect(navigation.path == [.sessionTaskStart(task: .chooseOrganization)])
    #expect(navigation.allTasksComplete == false)
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
