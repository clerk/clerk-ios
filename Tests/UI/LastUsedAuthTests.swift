#if os(iOS) || os(macOS)
import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor struct LastUsedAuthTests {
  private let clerk = Clerk.preview(.signedOut)

  private func configureBiometricCredentialLastAuth(emailEnabled: Bool) {
    setTestResourceState(clerk, encoded: try! clerk.state.encode(),
                         path: ["lastAuthenticationStrategy"], value: .string("trusted_device"))
    setTestEnvironment(clerk, ["userSettings", "social"], .object([:]))
    setTestEnvironment(clerk, ["userSettings", "attributes", "email_address", "enabled"], .bool(emailEnabled))
    for key in clerk.environment.userSettings.attributes.keys {
      setTestEnvironment(clerk, ["userSettings", "attributes", key, "used_for_first_factor"],
                         .bool(key == "email_address" && emailEnabled))
    }
  }

  @Test func biometricCredentialStrategyShowsBadgeWhenAnotherMethodIsVisible() {
    configureBiometricCredentialLastAuth(emailEnabled: true)
    let lastUsedAuth = LastUsedAuth(clerk: clerk, biometricSignInIsVisible: true)
    #expect(lastUsedAuth == .biometricCredential)
    #expect(lastUsedAuth?.showsBiometricCredentialBadge == true)
  }

  @Test func biometricCredentialStrategyDoesNotShowBadgeWhenItIsTheOnlyVisibleMethod() {
    configureBiometricCredentialLastAuth(emailEnabled: false)
    #expect(LastUsedAuth(clerk: clerk, biometricSignInIsVisible: true) == nil)
  }
}
#endif
