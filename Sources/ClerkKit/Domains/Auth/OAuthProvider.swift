//
//  OAuthProvider.swift
//
//
//  Created by Mike Pitre on 10/18/23.
//

import Foundation
import RegexBuilder

/// A type that represents the OAuth provider.
public enum OAuthProvider: CaseIterable, Codable, Sendable, Equatable, Identifiable, Hashable { // swiftlint:disable:this type_body_length
  case facebook
  case google
  case hubspot
  case github
  case tiktok
  case gitlab
  case discord
  case twitter
  case twitch
  case linkedin
  case linkedinOidc
  case dropbox
  case atlassian
  case bitbucket
  case microsoft
  case notion
  case apple
  case line
  case instagram
  case coinbase
  case spotify
  case xero
  case box
  case slack
  case linear
  case huggingFace
  case custom(_ strategy: String)

  // **
  // When adding a new case, make sure to add it to the all cases array
  // (.custom SHOULD NOT be included)
  // **

  public static var allCases: [OAuthProvider] {
    [
      .facebook,
      .google,
      .hubspot,
      .github,
      .tiktok,
      .gitlab,
      .discord,
      .twitter,
      .twitch,
      .linkedin,
      .linkedinOidc,
      .dropbox,
      .atlassian,
      .bitbucket,
      .microsoft,
      .notion,
      .apple,
      .line,
      .instagram,
      .coinbase,
      .spotify,
      .xero,
      .box,
      .slack,
      .linear,
      .huggingFace,
    ]
  }

  @_documentation(visibility: internal)
  public var id: String { providerData.strategy }

  public init(strategy: String) {
    if let provider = Self.allCases.first(where: { $0.providerData.strategy == strategy }) {
      self = provider
    } else {
      self = .custom(strategy)
    }
  }

  /// Returns the string value of strategy for the OAuth provider.
  public var strategy: String {
    switch self {
    case let .custom(strategy):
      strategy
    default:
      providerData.strategy
    }
  }

  /// Returns the name for a built in OAuth provider.
  @MainActor
  public var name: String {
    switch self {
    case let .custom(strategy):
      if let socialConfig = Clerk.shared.environment.userSettings?.social.first(where: { socialConfig in
        socialConfig.value.strategy == strategy
      }) {
        return socialConfig.value.name
      }

      fallthrough
    default:
      return providerData.name
    }
  }

  /// The url to an the icon for the provider.
  ///
  /// - Parameters:
  ///     - darkMode: Will return the dark mode variant of the image. Does not apply to custom providers.
  @MainActor
  public func iconImageUrl(darkMode: Bool = false) -> URL? {
    switch self {
    case let .custom(strategy):
      if let socialConfig = Clerk.shared.environment.userSettings?.social.first(where: { socialConfig in
        socialConfig.value.strategy == strategy && socialConfig.value.logoUrl?.isEmptyTrimmed == false
      }) {
        return URL(string: socialConfig.value.logoUrl ?? "")
      }

      return nil

    default:
      if let socialConfig = Clerk.shared.environment.userSettings?.social.first(where: { socialConfig in
        socialConfig.value.strategy == strategy && socialConfig.value.logoUrl?.isEmptyTrimmed == false
      }) {
        if var logoUrl = socialConfig.value.logoUrl {
          if darkMode {
            logoUrl = logoUrl.replacingOccurrences(of: ".png", with: "-dark.png")
          }

          return URL(string: logoUrl)
        }
      }

      return nil
    }
  }

  private struct OAuthProviderData {
    public var provider: String
    public let strategy: String
    public let name: String
  }

  private var providerData: OAuthProviderData {
    switch self {
    case let .custom(strategy):
      .init(
        provider: "",
        strategy: strategy,
        name: ""
      )
    case .facebook:
      .init(
        provider: "facebook",
        strategy: "oauth_facebook",
        name: "Facebook"
      )
    case .google:
      .init(
        provider: "google",
        strategy: "oauth_google",
        name: "Google"
      )
    case .hubspot:
      .init(
        provider: "hubspot",
        strategy: "oauth_hubspot",
        name: "HubSpot"
      )
    case .github:
      .init(
        provider: "github",
        strategy: "oauth_github",
        name: "GitHub"
      )
    case .tiktok:
      .init(
        provider: "tiktok",
        strategy: "oauth_tiktok",
        name: "TikTok"
      )
    case .gitlab:
      .init(
        provider: "gitlab",
        strategy: "oauth_gitlab",
        name: "GitLab"
      )
    case .discord:
      .init(
        provider: "discord",
        strategy: "oauth_discord",
        name: "Discord"
      )
    case .twitter:
      .init(
        provider: "twitter",
        strategy: "oauth_twitter",
        name: "Twitter"
      )
    case .twitch:
      .init(
        provider: "twitch",
        strategy: "oauth_twitch",
        name: "Twitch"
      )
    case .linkedin:
      .init(
        provider: "linkedin",
        strategy: "oauth_linkedin",
        name: "LinkedIn"
      )
    case .linkedinOidc:
      .init(
        provider: "linkedin_oidc",
        strategy: "oauth_linkedin_oidc",
        name: "LinkedIn"
      )
    case .dropbox:
      .init(
        provider: "dropbox",
        strategy: "oauth_dropbox",
        name: "Dropbox"
      )
    case .atlassian:
      .init(
        provider: "atlassian",
        strategy: "oauth_atlassian",
        name: "Atlassian"
      )
    case .bitbucket:
      .init(
        provider: "bitbucket",
        strategy: "oauth_bitbucket",
        name: "Bitbucket"
      )
    case .microsoft:
      .init(
        provider: "microsoft",
        strategy: "oauth_microsoft",
        name: "Microsoft"
      )
    case .notion:
      .init(
        provider: "notion",
        strategy: "oauth_notion",
        name: "Notion"
      )
    case .apple:
      .init(
        provider: "apple",
        strategy: "oauth_apple",
        name: "Apple"
      )
    case .line:
      .init(
        provider: "line",
        strategy: "oauth_line",
        name: "LINE"
      )
    case .instagram:
      .init(
        provider: "instagram",
        strategy: "oauth_instagram",
        name: "Instagram"
      )
    case .coinbase:
      .init(
        provider: "coinbase",
        strategy: "oauth_coinbase",
        name: "Coinbase"
      )
    case .spotify:
      .init(
        provider: "spotify",
        strategy: "oauth_spotify",
        name: "Spotify"
      )
    case .xero:
      .init(
        provider: "xero",
        strategy: "oauth_xero",
        name: "Xero"
      )
    case .box:
      .init(
        provider: "box",
        strategy: "oauth_box",
        name: "Box"
      )
    case .slack:
      .init(
        provider: "slack",
        strategy: "oauth_slack",
        name: "Slack"
      )
    case .linear:
      .init(
        provider: "linear",
        strategy: "oauth_linear",
        name: "Linear"
      )
    case .huggingFace:
      .init(
        provider: "huggingface",
        strategy: "oauth_huggingface",
        name: "Hugging Face"
      )
    }
  }
}

extension OAuthProvider: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
    let lhsName = lhs.providerData.name
    let rhsName = rhs.providerData.name

    if lhsName.isEmpty, rhsName.isEmpty {
      return false
    } else if lhsName.isEmpty {
      return false
    } else if rhsName.isEmpty {
      return true
    }

    return lhsName < rhsName
  }
}
