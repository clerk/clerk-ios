@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct OAuthProviderTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func supportsTintedIconMaskMatchesBuiltInAllowlist() {
    #expect(OAuthProvider.apple.supportsTintedIconMask == true)
    #expect(OAuthProvider.github.supportsTintedIconMask == true)
    #expect(OAuthProvider.vercel.supportsTintedIconMask == true)
    #expect(OAuthProvider.x.supportsTintedIconMask == true)
    #expect(OAuthProvider.google.supportsTintedIconMask == false)
    #expect(OAuthProvider.twitter.supportsTintedIconMask == false)
    #expect(OAuthProvider.custom("oauth_custom_acme").supportsTintedIconMask == false)
  }

  @Test
  func xProviderUsesOAuthXStrategy() {
    #expect(OAuthProvider.x.strategy == "oauth_x")
    #expect(OAuthProvider(strategy: "oauth_x") == .x)
  }

  @Test
  func iconImageUrlUsesConfiguredProviderLogoUrl() throws {
    let previousEnvironment = Clerk.shared.environment
    Clerk.shared.environment = makeEnvironmentWithSocialLogos()
    defer { Clerk.shared.environment = previousEnvironment }

    let expected = try #require(URL(string: "https://img.clerk.com/static/apple.png"))
    let iconUrl = try #require(OAuthProvider.apple.iconImageUrl)

    #expect(iconUrl == expected)
  }

  @Test
  func customProviderUsesConfiguredLogoUrlWithoutDarkVariantLookup() {
    let previousEnvironment = Clerk.shared.environment
    Clerk.shared.environment = makeEnvironmentWithSocialLogos()
    defer { Clerk.shared.environment = previousEnvironment }

    let provider = OAuthProvider.custom("oauth_custom_acme")
    #expect(provider.iconImageUrl == nil)
  }
}

@MainActor
private func makeEnvironmentWithSocialLogos() -> Clerk.Environment {
  var environment = Clerk.Environment.mock

  environment.userSettings.social.oauthApple.logoUrl = "https://img.clerk.com/static/apple.png"
  environment.userSettings.social.oauthGoogle.logoUrl = "https://img.clerk.com/static/google.png"
  environment.userSettings.social["oauth_github"] = .init(
    enabled: true,
    required: false,
    authenticatable: true,
    strategy: "oauth_github",
    name: "GitHub",
    logoUrl: "https://img.clerk.com/static/github.png"
  )
  environment.userSettings.social["oauth_vercel"] = .init(
    enabled: true,
    required: false,
    authenticatable: true,
    strategy: "oauth_vercel",
    name: "Vercel",
    logoUrl: "https://img.clerk.com/static/vercel.png"
  )
  environment.userSettings.social["oauth_x"] = .init(
    enabled: true,
    required: false,
    authenticatable: true,
    strategy: "oauth_x",
    name: "X / Twitter",
    logoUrl: "https://img.clerk.com/static/x.png"
  )
  return environment
}
