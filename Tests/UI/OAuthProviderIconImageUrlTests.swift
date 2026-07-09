@testable import ClerkKit
@testable import ClerkKitUI
import SwiftUI
import Testing

@MainActor
@Suite(.serialized)
struct OAuthProviderIconImageUrlTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  @Test
  func darkSchemeUsesDarkPngVariantForNonTintableClerkStaticProvider() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) {
      let url = try #require(OAuthProvider.notion.iconImageUrl(colorScheme: .dark))

      #expect(url == URL(string: "https://img.clerk.com/static/notion-dark.png"))
    }
  }

  @Test
  func lightSchemeUsesConfiguredProviderLogoUrl() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) {
      let url = try #require(OAuthProvider.notion.iconImageUrl(colorScheme: .light))

      #expect(url == URL(string: "https://img.clerk.com/static/notion.png"))
    }
  }

  @Test
  func darkSchemeDoesNotRewriteTintableProviderLogoUrl() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) {
      let url = try #require(OAuthProvider.x.iconImageUrl(colorScheme: .dark))

      #expect(url == URL(string: "https://img.clerk.com/static/x.png"))
    }
  }

  @Test
  func darkSchemeDoesNotRewriteNonClerkProviderLogoUrl() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) {
      let provider = OAuthProvider.custom("oauth_custom_acme")
      let url = try #require(provider.iconImageUrl(colorScheme: .dark))

      #expect(url == URL(string: "https://cdn.example.com/acme-logo.png"))
    }
  }

  @Test
  func darkSchemeDoesNotRewriteCustomClerkStaticProviderLogoUrl() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos(customLogoUrl: "https://img.clerk.com/static/acme.png")) {
      let provider = OAuthProvider.custom("oauth_custom_acme")
      let url = try #require(provider.iconImageUrl(colorScheme: .dark))

      #expect(url == URL(string: "https://img.clerk.com/static/acme.png"))
    }
  }

  @Test
  func darkSchemeDoesNotRewriteSvgProviderLogoUrl() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos(notionLogoUrl: "https://img.clerk.com/static/notion.svg")) {
      let url = try #require(OAuthProvider.notion.iconImageUrl(colorScheme: .dark))

      #expect(url == URL(string: "https://img.clerk.com/static/notion.svg"))
    }
  }

  @Test
  func darkSchemeUsesLinkedInDarkPngVariantForLinkedInOidc() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) {
      let url = try #require(OAuthProvider.linkedinOidc.iconImageUrl(colorScheme: .dark))

      #expect(url == URL(string: "https://img.clerk.com/static/linkedin-dark.png"))
    }
  }

  @Test
  func prefetchUrlsIncludeConfiguredAndDarkVariantForNonTintableClerkStaticPng() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) {
      let configuredUrl = try #require(URL(string: "https://img.clerk.com/static/notion.png"))
      let darkVariantUrl = try #require(URL(string: "https://img.clerk.com/static/notion-dark.png"))

      #expect(OAuthProvider.notion.iconImageUrlsForPrefetch == Set([configuredUrl, darkVariantUrl]))
    }
  }

  @Test
  func prefetchUrlsIncludeLinkedInOidcAndLinkedInDarkVariant() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) {
      let configuredUrl = try #require(URL(string: "https://img.clerk.com/static/linkedin_oidc.png"))
      let darkVariantUrl = try #require(URL(string: "https://img.clerk.com/static/linkedin-dark.png"))

      #expect(OAuthProvider.linkedinOidc.iconImageUrlsForPrefetch == Set([configuredUrl, darkVariantUrl]))
    }
  }

  @Test
  func prefetchUrlsDoNotAddDarkVariantForTintableProvider() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) {
      let configuredUrl = try #require(URL(string: "https://img.clerk.com/static/x.png"))

      #expect(OAuthProvider.x.iconImageUrlsForPrefetch == Set([configuredUrl]))
    }
  }

  @Test
  func prefetchUrlsDoNotAddDarkVariantForNonClerkProvider() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos()) {
      let provider = OAuthProvider.custom("oauth_custom_acme")
      let configuredUrl = try #require(URL(string: "https://cdn.example.com/acme-logo.png"))

      #expect(provider.iconImageUrlsForPrefetch == Set([configuredUrl]))
    }
  }

  @Test
  func prefetchUrlsDoNotAddDarkVariantForCustomClerkStaticProvider() throws {
    try withEnvironment(makeEnvironmentWithProviderLogos(customLogoUrl: "https://img.clerk.com/static/acme.png")) {
      let provider = OAuthProvider.custom("oauth_custom_acme")
      let configuredUrl = try #require(URL(string: "https://img.clerk.com/static/acme.png"))

      #expect(provider.iconImageUrlsForPrefetch == Set([configuredUrl]))
    }
  }
}

private let testPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

@MainActor
private func withEnvironment(_ environment: Clerk.Environment, perform assertions: () throws -> Void) rethrows {
  let previousEnvironment = Clerk.shared.environment
  Clerk.shared.environment = environment
  defer { Clerk.shared.environment = previousEnvironment }

  try assertions()
}

@MainActor
private func makeEnvironmentWithProviderLogos(
  notionLogoUrl: String = "https://img.clerk.com/static/notion.png",
  customLogoUrl: String = "https://cdn.example.com/acme-logo.png"
) -> Clerk.Environment {
  var environment = Clerk.Environment.mock

  environment.userSettings.social["oauth_notion"] = .init(
    enabled: true,
    required: false,
    authenticatable: true,
    strategy: "oauth_notion",
    notSelectable: false,
    name: "Notion",
    logoUrl: notionLogoUrl
  )
  environment.userSettings.social["oauth_x"] = .init(
    enabled: true,
    required: false,
    authenticatable: true,
    strategy: "oauth_x",
    notSelectable: false,
    name: "X / Twitter",
    logoUrl: "https://img.clerk.com/static/x.png"
  )
  environment.userSettings.social["oauth_linkedin_oidc"] = .init(
    enabled: true,
    required: false,
    authenticatable: true,
    strategy: "oauth_linkedin_oidc",
    notSelectable: false,
    name: "LinkedIn",
    logoUrl: "https://img.clerk.com/static/linkedin_oidc.png"
  )
  environment.userSettings.social["oauth_custom_acme"] = .init(
    enabled: true,
    required: false,
    authenticatable: true,
    strategy: "oauth_custom_acme",
    notSelectable: false,
    name: "Acme",
    logoUrl: customLogoUrl
  )

  return environment
}
