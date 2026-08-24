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
  func clientTrustModeSurvivesAlternativeMethodNavigation() {
    let factor = Factor(strategy: .passkey)

    #expect(
      SignInFactorMode.clientTrust.alternativeMethodsDestination(currentFactor: factor)
        == .signInClientTrustUseAnotherMethod(currentFactor: factor)
    )
    #expect(
      SignInFactorMode.clientTrust.destination(for: factor)
        == .signInClientTrust(factor: factor)
    )
  }
}

#endif
