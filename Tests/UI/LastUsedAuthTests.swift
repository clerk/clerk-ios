#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
@Suite(.serialized)
struct LastUsedAuthTests {
  @Test
  func trustedDeviceStrategyShowsTrustedDeviceBadgeWhenAnotherMethodIsVisible() {
    configureTrustedDeviceLastAuth()
    defer { Clerk.shared.client = .mock }
    var environment = Clerk.Environment.mock
    environment.userSettings.social = [:]
    for key in environment.userSettings.attributes.keys where key != "email_address" {
      environment.userSettings.attributes[key]?.usedForFirstFactor = false
    }

    let lastUsedAuth = LastUsedAuth(
      environment: environment,
      trustedDeviceSignInIsVisible: true
    )

    #expect(lastUsedAuth == .trustedDevice)
    #expect(lastUsedAuth?.showsTrustedDeviceBadge == true)
  }

  @Test
  func trustedDeviceStrategyDoesNotShowBadgeWhenOnlyTrustedDeviceIsVisible() {
    configureTrustedDeviceLastAuth()
    defer { Clerk.shared.client = .mock }
    var environment = Clerk.Environment.mock
    environment.userSettings.social = [:]
    for key in environment.userSettings.attributes.keys {
      environment.userSettings.attributes[key]?.usedForFirstFactor = false
    }

    let lastUsedAuth = LastUsedAuth(
      environment: environment,
      trustedDeviceSignInIsVisible: true
    )

    #expect(lastUsedAuth == nil)
  }

  private func configureTrustedDeviceLastAuth() {
    Clerk.configure(publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk")
    var client = Client.mock
    client.lastAuthenticationStrategy = .trustedDevice
    Clerk.shared.client = client
  }
}

#endif
