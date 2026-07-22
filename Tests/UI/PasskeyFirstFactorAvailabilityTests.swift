@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct PasskeyFirstFactorAvailabilityTests {
  private func environment(
    passkeyEnabled: Bool,
    usedForFirstFactor: Bool
  ) -> Clerk.Environment {
    var environment = Clerk.Environment.mock
    environment.userSettings.attributes["passkey"] = .init(
      enabled: passkeyEnabled,
      required: false,
      usedForFirstFactor: usedForFirstFactor,
      firstFactors: usedForFirstFactor ? ["passkey"] : [],
      usedForSecondFactor: false,
      secondFactors: [],
      verifications: ["passkey"],
      verifyAtSignUp: false
    )
    return environment
  }

  @Test
  func passkeyFirstFactorIsEnabledWhenPasskeyIsAFirstFactor() {
    let environment = environment(passkeyEnabled: true, usedForFirstFactor: true)

    #expect(environment.passkeyIsEnabled)
    #expect(environment.passkeyFirstFactorIsEnabled)
  }

  @Test
  func passkeyFirstFactorIsDisabledWhenPasskeyIsRegistrationOnly() {
    let environment = environment(passkeyEnabled: true, usedForFirstFactor: false)

    #expect(environment.passkeyIsEnabled)
    #expect(!environment.passkeyFirstFactorIsEnabled)
  }

  @Test
  func passkeyFirstFactorIsDisabledWhenPasskeyIsDisabled() {
    let environment = environment(passkeyEnabled: false, usedForFirstFactor: true)

    #expect(!environment.passkeyIsEnabled)
    #expect(!environment.passkeyFirstFactorIsEnabled)
  }

  @Test
  func passkeyFirstFactorIsDisabledWhenPasskeyIsDisabledAndNotAFirstFactor() {
    let environment = environment(passkeyEnabled: false, usedForFirstFactor: false)

    #expect(!environment.passkeyIsEnabled)
    #expect(!environment.passkeyFirstFactorIsEnabled)
  }

  @Test
  func passkeyFirstFactorIsDisabledWhenPasskeyAttributeIsAbsent() {
    #expect(!Clerk.Environment.mock.passkeyFirstFactorIsEnabled)
  }
}
