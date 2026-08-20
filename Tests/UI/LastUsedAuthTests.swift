#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
@Suite(.serialized)
struct LastUsedAuthTests {
  @Test
  func biometricCredentialStrategyShowsBiometricCredentialBadgeWhenAnotherMethodIsVisible() {
    configureBiometricCredentialLastAuth()
    defer { Clerk.shared.client = .mock }
    var environment = Clerk.Environment.mock
    environment.userSettings.social = [:]
    for key in environment.userSettings.attributes.keys where key != "email_address" {
      environment.userSettings.attributes[key]?.usedForFirstFactor = false
    }

    let lastUsedAuth = LastUsedAuth(
      environment: environment,
      biometricSignInIsVisible: true
    )

    #expect(lastUsedAuth == .biometricCredential)
    #expect(lastUsedAuth?.showsBiometricCredentialBadge == true)
  }

  @Test
  func biometricCredentialStrategyDoesNotShowBadgeWhenOnlyBiometricCredentialIsVisible() {
    configureBiometricCredentialLastAuth()
    defer { Clerk.shared.client = .mock }
    var environment = Clerk.Environment.mock
    environment.userSettings.social = [:]
    for key in environment.userSettings.attributes.keys {
      environment.userSettings.attributes[key]?.usedForFirstFactor = false
    }

    let lastUsedAuth = LastUsedAuth(
      environment: environment,
      biometricSignInIsVisible: true
    )

    #expect(lastUsedAuth == nil)
  }

  private func configureBiometricCredentialLastAuth() {
    Clerk.configure(publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk")
    var client = Client.mock
    client.lastAuthenticationStrategy = .biometricCredential
    Clerk.shared.client = client
  }
}

#endif
