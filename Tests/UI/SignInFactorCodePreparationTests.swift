#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

struct SignInFactorCodePreparationTests {
  @Test
  func sendsTheFirstCode() {
    #expect(SignInFactorCodeView.needsPrepare(
      factorStrategy: .emailCode,
      currentVerification: nil,
      isFirstRequest: true,
      lastCodeWasSentHere: false
    ))
  }

  @Test
  func resendsAfterSwitchingToEmailLinkAndBack() {
    #expect(SignInFactorCodeView.needsPrepare(
      factorStrategy: .emailCode,
      currentVerification: Verification(status: .unverified, strategy: .emailLink),
      isFirstRequest: false,
      lastCodeWasSentHere: true
    ))
  }

  @Test
  func resendsAfterSwitchingToAnotherFactorWithTheSameStrategyAndBack() {
    #expect(SignInFactorCodeView.needsPrepare(
      factorStrategy: .phoneCode,
      currentVerification: Verification(status: .unverified, strategy: .phoneCode),
      isFirstRequest: false,
      lastCodeWasSentHere: false
    ))
  }

  @Test
  func doesNotResendWhenThisFactorHasTheCurrentCode() {
    #expect(!SignInFactorCodeView.needsPrepare(
      factorStrategy: .emailCode,
      currentVerification: Verification(status: .unverified, strategy: .emailCode),
      isFirstRequest: false,
      lastCodeWasSentHere: true
    ))
  }

  @Test
  func doesNotResendAfterTheStepIsVerified() {
    #expect(!SignInFactorCodeView.needsPrepare(
      factorStrategy: .emailCode,
      currentVerification: Verification(status: .verified, strategy: .emailCode),
      isFirstRequest: false,
      lastCodeWasSentHere: false
    ))
  }

  @Test
  func sendsAResetCodeAfterAnEmailCodeForTheSameAddress() {
    #expect(SignInFactorCodeView.needsPrepare(
      factorStrategy: .resetPasswordEmailCode,
      currentVerification: Verification(status: .unverified, strategy: .emailCode),
      isFirstRequest: false,
      lastCodeWasSentHere: true
    ))
  }

  @Test
  func doesNotPrepareTotpAgain() {
    #expect(!SignInFactorCodeView.needsPrepare(
      factorStrategy: .totp,
      currentVerification: Verification(status: .unverified, strategy: .phoneCode),
      isFirstRequest: false,
      lastCodeWasSentHere: false
    ))
  }
}

#endif
