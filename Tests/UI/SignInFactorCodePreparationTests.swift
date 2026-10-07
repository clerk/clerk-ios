#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

struct SignInFactorCodePreparationTests {
  @Test
  func sendsTheFirstCode() {
    #expect(SignInFactorCodeView.needsPrepare(
      factorStrategy: .emailCode,
      isFirstRequest: true,
      currentVerificationStrategy: nil
    ))
  }

  @Test
  func resendsAfterSwitchingToEmailLinkAndBack() {
    #expect(SignInFactorCodeView.needsPrepare(
      factorStrategy: .emailCode,
      isFirstRequest: false,
      currentVerificationStrategy: .emailLink
    ))
  }

  @Test
  func doesNotResendWhenTheCurrentVerificationMatches() {
    #expect(!SignInFactorCodeView.needsPrepare(
      factorStrategy: .emailCode,
      isFirstRequest: false,
      currentVerificationStrategy: .emailCode
    ))
    #expect(!SignInFactorCodeView.needsPrepare(
      factorStrategy: .phoneCode,
      isFirstRequest: false,
      currentVerificationStrategy: .phoneCode
    ))
  }

  @Test
  func sendsAResetCodeAfterAnEmailCodeForTheSameAddress() {
    #expect(SignInFactorCodeView.needsPrepare(
      factorStrategy: .resetPasswordEmailCode,
      isFirstRequest: false,
      currentVerificationStrategy: .emailCode
    ))
  }

  @Test
  func doesNotPrepareTotpAgain() {
    #expect(!SignInFactorCodeView.needsPrepare(
      factorStrategy: .totp,
      isFirstRequest: false,
      currentVerificationStrategy: .emailCode
    ))
  }
}

#endif
