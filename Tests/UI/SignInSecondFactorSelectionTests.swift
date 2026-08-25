#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

struct SignInSecondFactorSelectionTests {
  @Test
  func startingSecondFactorPrefersPasskey() {
    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsSecondFactor,
      supportedSecondFactors: [
        Factor(strategy: .phoneCode),
        Factor(strategy: .totp),
        Factor(strategy: .passkey),
      ]
    )

    #expect(signIn.startingSecondFactor?.strategy == .passkey)
  }

  @Test
  func alternativeSecondFactorsUseCompletePreferenceOrder() {
    let backupCode = Factor(strategy: .backupCode)
    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsSecondFactor,
      supportedSecondFactors: [
        backupCode,
        Factor(strategy: .phoneCode),
        Factor(strategy: .unknown("future_strategy")),
        Factor(strategy: .emailCode),
        Factor(strategy: .totp),
        Factor(strategy: .passkey),
      ]
    )

    let strategies = signIn.alternativeSecondFactors(currentFactor: backupCode).map(\.strategy)

    #expect(strategies == [
      .passkey,
      .totp,
      .phoneCode,
      .emailCode,
      .unknown("future_strategy"),
    ])
  }
}

#endif
