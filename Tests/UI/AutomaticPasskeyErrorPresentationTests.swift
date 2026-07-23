import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct AutomaticPasskeyErrorPresentationTests {
  @Test(arguments: [
    PasskeyAuthenticationFailure.Stage.preparingFirstFactor,
    .requestingAuthorization,
  ])
  func errorsBeforeFirstFactorAttemptAreNotPresented(
    _ stage: PasskeyAuthenticationFailure.Stage
  ) {
    #expect(!AuthStartView.shouldPresentAutomaticPasskeyError(at: stage))
  }

  @Test
  func firstFactorAttemptErrorIsPresented() {
    #expect(AuthStartView.shouldPresentAutomaticPasskeyError(at: .attemptingFirstFactor))
  }
}
