@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct OAuthProviderTests {
  @Test
  func supportsTintedIconMaskMatchesBuiltInAllowlist() {
    #expect(OAuthProvider.apple.supportsTintedIconMask == true)
    #expect(OAuthProvider.github.supportsTintedIconMask == true)
    #expect(OAuthProvider.vercel.supportsTintedIconMask == true)
    #expect(OAuthProvider.google.supportsTintedIconMask == false)
    #expect(OAuthProvider.custom("oauth_custom_acme").supportsTintedIconMask == false)
  }

  @Test
  func iconImageUrlUsesConfiguredProviderLogoUrl() throws {
    let environment = makeEnvironmentWithSocialLogos()
    let expected = try #require(URL(string: "https://img.clerk.com/static/apple.png"))
    let iconUrl = try #require(OAuthProvider.apple.iconImageUrl(in: environment))

    #expect(iconUrl == expected)
  }

  @Test
  func customProviderUsesConfiguredLogoUrlWithoutDarkVariantLookup() throws {
    let environment = makeEnvironmentWithSocialLogos()
    let provider = OAuthProvider.custom("oauth_custom_acme")
    let expected = try #require(URL(string: "https://cdn.example.com/acme-logo.png"))
    let iconUrl = try #require(provider.iconImageUrl(in: environment))

    #expect(iconUrl == expected)
  }
}

@MainActor
private func makeEnvironmentWithSocialLogos() -> Clerk.Environment {
  var environment = Clerk.Environment.mock

  environment.userSettings.social["oauth_apple"]?.logoUrl = "https://img.clerk.com/static/apple.png"
  environment.userSettings.social["oauth_google"]?.logoUrl = "https://img.clerk.com/static/google.png"
  environment.userSettings.social["oauth_github"] = .init(
    enabled: true,
    required: false,
    authenticatable: true,
    strategy: "oauth_github",
    notSelectable: false,
    name: "GitHub",
    logoUrl: "https://img.clerk.com/static/github.png"
  )
  environment.userSettings.social["oauth_vercel"] = .init(
    enabled: true,
    required: false,
    authenticatable: true,
    strategy: "oauth_vercel",
    notSelectable: false,
    name: "Vercel",
    logoUrl: "https://img.clerk.com/static/vercel.png"
  )
  environment.userSettings.social["oauth_custom_acme"] = .init(
    enabled: true,
    required: false,
    authenticatable: true,
    strategy: "oauth_custom_acme",
    notSelectable: false,
    name: "Acme",
    logoUrl: "https://cdn.example.com/acme-logo.png"
  )

  return environment
}
