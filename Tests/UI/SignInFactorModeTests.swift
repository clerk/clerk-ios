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

    #expect(!SignInFactorMode.clientTrust.showsUseAnotherMethod(signIn: onlyEmailCode, currentFactor: emailCode))
    #expect(SignInFactorMode.clientTrust.showsUseAnotherMethod(signIn: emailCodeAndLink, currentFactor: emailCode))
    #expect(SignInFactorMode.clientTrust.showsUseAnotherMethod(signIn: emailCodeAndLink, currentFactor: emailLink))
    #expect(SignInFactorMode.secondFactor.showsUseAnotherMethod(signIn: onlyEmailCode, currentFactor: emailCode))
    #expect(SignInFactorMode.firstFactor.showsUseAnotherMethod(signIn: nil, currentFactor: emailCode))
  }
}

#endif
