#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct SignInFactorOnePasswordViewTests {
  @Test
  func passwordResetRequiredOpensThePasswordResetRequiredScreen() {
    let destination = SignInFactorOnePasswordView.destination(
      afterPasswordError: ClerkAPIError(code: "password_reset_required"),
      signIn: signIn(canResetPassword: true)
    )

    #expect(destination == .signInPasswordResetRequired)
  }

  @Test
  func passwordResetRequiredStaysOnThePasswordScreenWhenThePasswordCannotBeReset() {
    let destination = SignInFactorOnePasswordView.destination(
      afterPasswordError: ClerkAPIError(code: "password_reset_required"),
      signIn: signIn(canResetPassword: false)
    )

    #expect(destination == nil)
  }

  @Test
  func otherPasswordErrorsStayOnThePasswordScreen() {
    let destination = SignInFactorOnePasswordView.destination(
      afterPasswordError: ClerkAPIError(code: "form_password_incorrect"),
      signIn: signIn(canResetPassword: true)
    )

    #expect(destination == nil)
  }

  private func signIn(canResetPassword: Bool) -> SignIn {
    var signIn = SignIn.mock
    signIn.status = .needsFirstFactor
    if canResetPassword {
      signIn.supportedFirstFactors?.append(.mockResetPasswordEmailCode)
    }
    return signIn
  }
}

#endif
