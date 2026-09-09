@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct PasskeyFirstFactorAvailabilityTests {
  private let clerk = Clerk.preview(.signedOut)

  private func environment(
    passkeyEnabled: Bool,
    usedForFirstFactor: Bool
  ) -> EnvironmentResource {
    setTestEnvironment(clerk, ["userSettings", "attributes", "passkey"], .object([
      "enabled": .bool(passkeyEnabled), "required": .bool(false),
      "used_for_first_factor": .bool(usedForFirstFactor),
      "first_factors": .array(usedForFirstFactor ? [.string("passkey")] : []),
      "used_for_second_factor": .bool(false), "second_factors": .array([]),
      "verifications": .array([.string("passkey")]), "verify_at_sign_up": .bool(false),
      "name": .string("passkey"),
    ]))
    return clerk.environment
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
    #expect(!Clerk.preview(.signedOut).environment.passkeyFirstFactorIsEnabled)
  }
}
