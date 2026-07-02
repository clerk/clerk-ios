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
    #expect(navigation.allTasksComplete == false)
  }

  @Test
  func handleSessionTaskCompletionMarksAllTasksCompleteWhenSessionHasNoPendingTasks() {
    let navigation = AuthNavigation()
    let session = session(pendingTasks: [])

    navigation.handleSessionTaskCompletion(session: session)

    #expect(navigation.path.isEmpty)
    #expect(navigation.allTasksComplete)
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
