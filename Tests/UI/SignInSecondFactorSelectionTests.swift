#if os(iOS) || os(macOS)
import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor struct SignInSecondFactorSelectionTests {
  private let clerk = Clerk.preview(.signedOut)

  private func signIn(_ factors: [SignInSecondFactor]) -> SignIn {
    setTestResourceState(clerk.signIn, encoded: try! clerk.signIn.state.encode(),
                         path: ["supportedSecondFactors"], value: .array(try! factors.map { try $0.encode() }))
    return clerk.signIn
  }

  @Test func startingSecondFactorPrefersPasskey() {
    let signIn = signIn([
      .case3(.init(phoneNumberId: "phone_123", safeIdentifier: "+15555550100")),
      .case5(.init()), .case4(.init()),
    ])
    #expect(signIn.startingSecondFactor?.strategy == .passkey)
  }

  @Test func alternativeSecondFactorsUseCompletePreferenceOrder() {
    let signIn = signIn([
      .case6(.init()), .case3(.init(phoneNumberId: "phone_123", safeIdentifier: "+15555550100")),
      .case1(.init(emailAddressId: "email_123", safeIdentifier: "user@example.com")),
      .case5(.init()), .case4(.init()),
    ])
    let strategies = signIn.alternativeSecondFactors(currentFactor: Factor(strategy: .backupCode)).map(\.strategy)
    #expect(strategies == [.passkey, .totp, .phoneCode, .emailCode])
  }

  @Test func unknownPresentationStrategiesSortAfterSupportedFactors() {
    let factors = [Factor(strategy: .unknown("future_strategy")), Factor(strategy: .emailCode), Factor(strategy: .passkey)]
    #expect(factors.sorted(using: Factor.backupCodePrefComparator).map(\.strategy) == [.passkey, .emailCode, .unknown("future_strategy")])
  }
}
#endif
