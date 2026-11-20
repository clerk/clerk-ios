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

  @Test
  func latePasswordResponseCannotReplaceAnotherScreenOrAttempt() {
    let attempt = signIn(canResetPassword: true)
    let navigation = AuthNavigation()
    navigation.path = [.signInFactorOne(factor: .mockPassword)]
    let submittedPath = navigation.path
    navigation.path.append(.signInForgotPassword)
    #expect(!SignInFactorOnePasswordView.isCurrentSubmission(
      attemptID: attempt.id, submittedPath: submittedPath, signIn: attempt, navigation: navigation
    ))
    navigation.path = submittedPath
    #expect(!SignInFactorOnePasswordView.isCurrentSubmission(
      attemptID: "previous-attempt", submittedPath: submittedPath, signIn: attempt, navigation: navigation
    ))
    #expect(SignInFactorOnePasswordView.isCurrentSubmission(
      attemptID: attempt.id, submittedPath: submittedPath, signIn: attempt, navigation: navigation
    ))
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
