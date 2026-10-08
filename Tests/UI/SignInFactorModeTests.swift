#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

struct SignInFactorModeTests {
  @Test
  func clientTrustModeUsesSecondFactorAPIAndShowsWarning() {
    #expect(SignInFactorMode.clientTrust.usesSecondFactorAPI)
    #expect(SignInFactorMode.clientTrust.showsClientTrustWarning)
    #expect(!SignInFactorMode.secondFactor.showsClientTrustWarning)
  }

  @Test
  func clientTrustModeKeepsAlternativeMethodsInClientTrust() {
    let factor = Factor(strategy: .emailCode)

    #expect(
      SignInFactorMode.clientTrust.alternativeMethodsDestination(currentFactor: factor)
        == .signInClientTrustUseAnotherMethod(currentFactor: factor)
    )
    #expect(
      SignInFactorMode.clientTrust.destination(for: factor)
        == .signInClientTrust(factor: factor)
    )
  }

  @Test
  func clientTrustModeShowsUseAnotherMethodOnlyWhenAnotherFactorIsOffered() {
    let emailCode = Factor(strategy: .emailCode, emailAddressId: "ema_123", safeIdentifier: "sam@clerk.dev")
    let emailLink = Factor(strategy: .emailLink, emailAddressId: "ema_123", safeIdentifier: "sam@clerk.dev")
    let onlyEmailCode = SignIn(id: "sia_1", status: .needsClientTrust, supportedSecondFactors: [emailCode])
    let emailCodeAndLink = SignIn(id: "sia_2", status: .needsClientTrust, supportedSecondFactors: [emailCode, emailLink])

    #expect(!SignInFactorMode.clientTrust.showsUseAnotherMethod(signIn: onlyEmailCode, currentFactor: emailCode, socialProviders: []))
    #expect(SignInFactorMode.clientTrust.showsUseAnotherMethod(signIn: emailCodeAndLink, currentFactor: emailCode, socialProviders: []))
    #expect(SignInFactorMode.clientTrust.showsUseAnotherMethod(signIn: emailCodeAndLink, currentFactor: emailLink, socialProviders: []))
  }

  @Test
  func firstFactorShowsUseAnotherMethodOnlyWhenAnotherMethodOrProviderIsOffered() {
    let emailCode = Factor(strategy: .emailCode, emailAddressId: "ema_123", safeIdentifier: "sam@clerk.dev")
    let password = Factor(strategy: .password)
    let resetPassword = Factor(strategy: .resetPasswordEmailCode, emailAddressId: "ema_123", safeIdentifier: "sam@clerk.dev")
    let onlyEmailCode = SignIn(id: "sia_1", status: .needsFirstFactor, supportedFirstFactors: [emailCode])
    let passwordAndReset = SignIn(id: "sia_2", status: .needsFirstFactor, supportedFirstFactors: [password, resetPassword])
    let emailCodeAndPassword = SignIn(id: "sia_3", status: .needsFirstFactor, supportedFirstFactors: [emailCode, password])

    #expect(!SignInFactorMode.firstFactor.showsUseAnotherMethod(signIn: onlyEmailCode, currentFactor: emailCode, socialProviders: []))
    #expect(!SignInFactorMode.firstFactor.showsUseAnotherMethod(signIn: passwordAndReset, currentFactor: password, socialProviders: []))
    #expect(SignInFactorMode.firstFactor.showsUseAnotherMethod(signIn: onlyEmailCode, currentFactor: emailCode, socialProviders: [.google]))
    #expect(SignInFactorMode.firstFactor.showsUseAnotherMethod(signIn: emailCodeAndPassword, currentFactor: emailCode, socialProviders: []))
  }

  @Test
  func factorsTheAlternativesScreenCannotShowDoNotCountAsAlternatives() {
    let emailCode = Factor(strategy: .emailCode, emailAddressId: "ema_123", safeIdentifier: "sam@clerk.dev")
    let web3 = Factor(strategy: .unknown("web3_metamask_signature"))
    let phoneCodeWithoutIdentifier = Factor(strategy: .phoneCode)
    let firstFactorSignIn = SignIn(id: "sia_1", status: .needsFirstFactor, supportedFirstFactors: [emailCode, web3, phoneCodeWithoutIdentifier])
    let secondFactorSignIn = SignIn(id: "sia_2", status: .needsSecondFactor, supportedSecondFactors: [Factor(strategy: .totp), web3])

    #expect(!SignInFactorMode.firstFactor.showsUseAnotherMethod(signIn: firstFactorSignIn, currentFactor: emailCode, socialProviders: []))
    #expect(!SignInFactorMode.secondFactor.showsUseAnotherMethod(signIn: secondFactorSignIn, currentFactor: Factor(strategy: .totp), socialProviders: []))
  }

  @Test
  func secondFactorShowsUseAnotherMethodOnlyWhenAnotherFactorIsOffered() {
    let totp = Factor(strategy: .totp)
    let backupCode = Factor(strategy: .backupCode)
    let onlyTotp = SignIn(id: "sia_1", status: .needsSecondFactor, supportedSecondFactors: [totp])
    let totpAndBackupCode = SignIn(id: "sia_2", status: .needsSecondFactor, supportedSecondFactors: [totp, backupCode])

    #expect(!SignInFactorMode.secondFactor.showsUseAnotherMethod(signIn: onlyTotp, currentFactor: totp, socialProviders: [.google]))
    #expect(SignInFactorMode.secondFactor.showsUseAnotherMethod(signIn: totpAndBackupCode, currentFactor: totp, socialProviders: []))
    #expect(SignInFactorMode.secondFactor.showsUseAnotherMethod(signIn: totpAndBackupCode, currentFactor: backupCode, socialProviders: []))
  }
}

#endif
