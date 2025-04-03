import Factory
import Foundation
import Testing

@testable import Clerk

struct OAuthProviderTests {

  @Test func testInit() {
    let provider = OAuthProvider(strategy: "oauth_google")
    #expect(provider == .google)

    let customProvider = OAuthProvider(strategy: "oauth_custom")
    #expect(customProvider == .custom("oauth_custom"))
  }

  @Test func testId() {
    let provider = OAuthProvider.google
    #expect(provider.id == provider.strategy)

    let customProvider = OAuthProvider(strategy: "oauth_custom")
    #expect(customProvider.id == customProvider.strategy)
  }
}

@Suite(.serialized) struct OAuthProviderSerializedTests {

  init() {
    Container.shared.reset()
  }

  @MainActor
  @Test func testName() {
    let mockEnvironment = Clerk.Environment.init(
      userSettings: .init(
        attributes: [:],
        signUp: .init(customActionRequired: false, progressive: false, mode: "", legalConsentEnabled: false),
        social: [
          "oauth_custom_provider": .init(
            enabled: true,
            required: false,
            authenticatable: true,
            strategy: "oauth_custom_provider",
            notSelectable: false,
            name: "Custom Provider",
            logoUrl: "https://img.clerk.com/static/google.png"
          )
        ],
        actions: .init(),
        passkeySettings: nil
      )
    )

    Clerk.shared.environment = mockEnvironment
    // the clerk shared instance gets reset by Container.shared.reset() before each test

    let provider = OAuthProvider.google
    #expect(provider.name == "Google")

    let customProvider = OAuthProvider(strategy: "oauth_custom_provider")
    #expect(customProvider.name == "Custom Provider")

    let customProviderNotFound = OAuthProvider(strategy: "oauth_custom_invalid")
    #expect(customProviderNotFound.name == "")
  }

  @MainActor
  @Test func testIconImageUrl() {
    let mockEnvironment = Clerk.Environment.init(
      userSettings: .init(
        attributes: [:],
        signUp: .init(customActionRequired: false, progressive: false, mode: "", legalConsentEnabled: false),
        social: [
          "oauth_google": .init(
            enabled: true,
            required: false,
            authenticatable: true,
            strategy: "oauth_google",
            notSelectable: false,
            name: "Google",
            logoUrl: "https://img.clerk.com/static/google.png"
          ),
          "oauth_custom": .init(
            enabled: true,
            required: false,
            authenticatable: true,
            strategy: "oauth_custom",
            notSelectable: false,
            name: "Custom",
            logoUrl: "https://img.clerk.com/static/custom.png"
          ),
        ],
        actions: .init(),
        passkeySettings: nil
      )
    )

    Clerk.shared.environment = mockEnvironment
    // the clerk shared instance gets reset by Container.shared.reset() before each test

    let googleProvider = OAuthProvider.google
    #expect(googleProvider.iconImageUrl() == URL(string: "https://img.clerk.com/static/google.png")!)
    #expect(googleProvider.iconImageUrl(darkMode: true) == URL(string: "https://img.clerk.com/static/google-dark.png")!)

    let customProvider = OAuthProvider(strategy: "oauth_custom")
    #expect(customProvider.iconImageUrl(darkMode: false) == URL(string: "https://img.clerk.com/static/custom.png")!)
    #expect(customProvider.iconImageUrl(darkMode: true) == URL(string: "https://img.clerk.com/static/custom.png")!)  // customs dont have dark mode

    let customProviderNotFound = OAuthProvider(strategy: "oauth_custom_invalid")
    #expect(customProviderNotFound.iconImageUrl() == nil)

    let builtInProviderNotFound = OAuthProvider.tiktok
    #expect(builtInProviderNotFound.iconImageUrl() == nil)
  }

  @Test func testSorting() {
    let providers: [OAuthProvider] = [
      .google,
      .custom("invalid"),
      .apple,
      .facebook,
      .custom("also_invalid"),
    ]

    #expect(
      providers.sorted() == [
        .apple,
        .facebook,
        .google,
        .custom("invalid"),
        .custom("also_invalid"),
      ]
    )
  }

}
