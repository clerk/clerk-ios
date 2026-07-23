import AuthenticationServices
@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
struct AutomaticPasskeyErrorPresentationTests {
  private enum TestError: Error {
    case failed
  }

  @Test
  func noCredentialAuthorizationErrorIsNotPresented() {
    let error = ASAuthorizationError(
      .canceled,
      userInfo: [
        NSLocalizedFailureReasonErrorKey: "No credentials available for login.",
      ]
    )

    #expect(!AuthStartView.shouldPresentAutomaticPasskeyError(error))
  }

  @Test
  func authorizationErrorWithoutFailureReasonIsNotPresented() {
    let error = ASAuthorizationError(.failed)

    #expect(!AuthStartView.shouldPresentAutomaticPasskeyError(error))
  }

  @Test
  func preSelectionErrorIsNotPresented() {
    #expect(!AuthStartView.shouldPresentAutomaticPasskeyError(
      TestError.failed,
      isPreSelection: true
    ))
  }

  @Test
  func postSelectionNonAuthorizationErrorIsPresented() {
    #expect(AuthStartView.shouldPresentAutomaticPasskeyError(TestError.failed))
  }
}
