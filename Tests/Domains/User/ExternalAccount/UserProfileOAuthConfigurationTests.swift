#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

struct UserProfileOAuthConfigurationTests {
  @Test
  func requiresReauthorizationWhenNoScopesAreApproved() {
    let config = UserProfileOAuthConfiguration([
      OAuthProviderConfig(provider: .google, additionalScopes: ["calendar"]),
    ])
    var account = ExternalAccount.mockVerified
    account.approvedScopes = ""

    #expect(config.requiresReauthorization(for: account))
  }
}

#endif
