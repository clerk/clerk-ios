@testable import ClerkKit
@testable import ClerkKitUI
import SwiftUI
import Testing

@MainActor
@Suite(.serialized)
struct OAuthProviderIconImageUrlTests {
  @Test
  func darkSchemeUsesDarkPngVariantForNonTintableClerkStaticProvider() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) { environment in
      let url = try #require(OAuthProvider.notion.iconImageUrl(colorScheme: .dark, environment: environment))

      #expect(url == URL(string: "https://img.clerk.com/static/notion-dark.png"))
    }
  }

  @Test
  func lightSchemeUsesConfiguredProviderLogoUrl() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) { environment in
      let url = try #require(OAuthProvider.notion.iconImageUrl(colorScheme: .light, environment: environment))

      #expect(url == URL(string: "https://img.clerk.com/static/notion.png"))
    }
  }

  @Test
  func darkSchemeDoesNotRewriteTintableProviderLogoUrl() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) { environment in
      let url = try #require(OAuthProvider.x.iconImageUrl(colorScheme: .dark, environment: environment))

      #expect(url == URL(string: "https://img.clerk.com/static/x.png"))
    }
  }

  @Test
  func darkSchemeDoesNotRewriteNonClerkProviderLogoUrl() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) { environment in
      let provider = OAuthProvider.unrecognized("custom_acme")
      let url = try #require(provider.iconImageUrl(colorScheme: .dark, environment: environment))

      #expect(url == URL(string: "https://cdn.example.com/acme-logo.png"))
    }
  }

  @Test
  func darkSchemeDoesNotRewriteCustomClerkStaticProviderLogoUrl() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos(customLogoUrl: "https://img.clerk.com/static/acme.png")) { environment in
      let provider = OAuthProvider.unrecognized("custom_acme")
      let url = try #require(provider.iconImageUrl(colorScheme: .dark, environment: environment))

      #expect(url == URL(string: "https://img.clerk.com/static/acme.png"))
    }
  }

  @Test
  func darkSchemeDoesNotRewriteSvgProviderLogoUrl() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos(notionLogoUrl: "https://img.clerk.com/static/notion.svg")) { environment in
      let url = try #require(OAuthProvider.notion.iconImageUrl(colorScheme: .dark, environment: environment))

      #expect(url == URL(string: "https://img.clerk.com/static/notion.svg"))
    }
  }

  @Test
  func darkSchemeUsesLinkedInDarkPngVariantForLinkedInOidc() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) { environment in
      let url = try #require(OAuthProvider.linkedinOidc.iconImageUrl(colorScheme: .dark, environment: environment))

      #expect(url == URL(string: "https://img.clerk.com/static/linkedin-dark.png"))
    }
  }

  @Test
  func prefetchUrlsIncludeConfiguredAndDarkVariantForNonTintableClerkStaticPng() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) { environment in
      let configuredUrl = try #require(URL(string: "https://img.clerk.com/static/notion.png"))
      let darkVariantUrl = try #require(URL(string: "https://img.clerk.com/static/notion-dark.png"))

      #expect(OAuthProvider.notion.iconImageUrlsForPrefetch(environment: environment) == Set([configuredUrl, darkVariantUrl]))
    }
  }

  @Test
  func prefetchUrlsIncludeLinkedInOidcAndLinkedInDarkVariant() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) { environment in
      let configuredUrl = try #require(URL(string: "https://img.clerk.com/static/linkedin_oidc.png"))
      let darkVariantUrl = try #require(URL(string: "https://img.clerk.com/static/linkedin-dark.png"))

      #expect(OAuthProvider.linkedinOidc.iconImageUrlsForPrefetch(environment: environment) == Set([configuredUrl, darkVariantUrl]))
    }
  }

  @Test
  func prefetchUrlsDoNotAddDarkVariantForTintableProvider() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) { environment in
      let configuredUrl = try #require(URL(string: "https://img.clerk.com/static/x.png"))

      #expect(OAuthProvider.x.iconImageUrlsForPrefetch(environment: environment) == Set([configuredUrl]))
    }
  }

  @Test
  func prefetchUrlsDoNotAddDarkVariantForNonClerkProvider() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) { environment in
      let provider = OAuthProvider.unrecognized("custom_acme")
      let configuredUrl = try #require(URL(string: "https://cdn.example.com/acme-logo.png"))

      #expect(provider.iconImageUrlsForPrefetch(environment: environment) == Set([configuredUrl]))
    }
  }

  @Test
  func prefetchUrlsDoNotAddDarkVariantForCustomClerkStaticProvider() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos(customLogoUrl: "https://img.clerk.com/static/acme.png")) { environment in
      let provider = OAuthProvider.unrecognized("custom_acme")
      let configuredUrl = try #require(URL(string: "https://img.clerk.com/static/acme.png"))

      #expect(provider.iconImageUrlsForPrefetch(environment: environment) == Set([configuredUrl]))
    }
  }
}

@MainActor
private func withEnvironment(_ clerk: Clerk, perform assertions: (EnvironmentResource) throws -> Void) rethrows {
  try assertions(clerk.environment)
}

@MainActor
private func makeEnvironmentWithProviderLogos(
  notionLogoUrl: String = "https://img.clerk.com/static/notion.png",
  customLogoUrl: String = "https://cdn.example.com/acme-logo.png"
) -> Clerk {
  let clerk = Clerk.preview(.signedOut)
  for (strategy, logo) in [
    "oauth_notion": notionLogoUrl,
    "oauth_x": "https://img.clerk.com/static/x.png",
    "oauth_linkedin_oidc": "https://img.clerk.com/static/linkedin_oidc.png",
    "oauth_custom_acme": customLogoUrl,
  ] {
    setTestEnvironment(clerk, ["userSettings", "social", strategy], .object([
      "enabled": .bool(true), "required": .bool(false), "authenticatable": .bool(true),
      "strategy": .string(strategy), "name": .string(strategy), "logo_url": .string(logo),
    ]))
  }
  return clerk
}
