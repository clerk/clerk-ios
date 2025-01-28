//
//  OAuthProvider.swift
//
//
//  Created by Mike Pitre on 10/18/23.
//

import Foundation
import RegexBuilder

/// A type that represents the OAuth provider.
public enum OAuthProvider: CaseIterable, Codable, Sendable, Equatable, Identifiable, Hashable {
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
    case linkedin_oidc
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
    
    static public var allCases: [OAuthProvider] {
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
            .linkedin_oidc,
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
            .huggingFace
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
        case .custom(let strategy):
            return strategy
        default:
            return providerData.strategy
        }
    }
    
    /// Returns the name for a built in OAuth provider.
    @MainActor
    public var name: String {
        switch self {
        case .custom(let strategy):
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
    
    /// The icon of the provider.
    ///
    /// - Parameters:
    ///     - darkMode: Will return the dark mode variant of the image. Does not apply to custom providers.
    @MainActor
    func iconImageUrl(darkMode: Bool = false) -> URL? {
        switch self {
        case .custom(let strategy):
            if let socialConfig = Clerk.shared.environment.userSettings?.social.first(where: { socialConfig in
                socialConfig.value.strategy == strategy && socialConfig.value.logoUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }) {
                return URL(string: socialConfig.value.logoUrl ?? "")
            }
            
            return nil
            
        default:
                
            if let socialConfig = Clerk.shared.environment.userSettings?.social.first(where: { socialConfig in
                socialConfig.value.strategy == strategy && socialConfig.value.logoUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
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
        case .custom(let strategy):
            return .init(
                provider: "",
                strategy: strategy,
                name: ""
            )
        case .facebook:
            return .init(
                provider: "facebook",
                strategy: "oauth_facebook",
                name: "Facebook"
            )
        case .google:
            return .init(
                provider: "google",
                strategy: "oauth_google",
                name: "Google"
            )
        case .hubspot:
            return .init(
                provider: "hubspot",
                strategy: "oauth_hubspot",
                name: "HubSpot"
            )
        case .github:
            return .init(
                provider: "github",
                strategy: "oauth_github",
                name: "GitHub"
            )
        case .tiktok:
            return .init(
                provider: "tiktok",
                strategy: "oauth_tiktok",
                name: "TikTok"
            )
        case .gitlab:
            return .init(
                provider: "gitlab",
                strategy: "oauth_gitlab",
                name: "GitLab"
            )
        case .discord:
            return .init(
                provider: "discord",
                strategy: "oauth_discord",
                name: "Discord"
            )
        case .twitter:
            return .init(
                provider: "twitter",
                strategy: "oauth_twitter",
                name: "Twitter"
            )
        case .twitch:
            return .init(
                provider: "twitch",
                strategy: "oauth_twitch",
                name: "Twitch"
            )
        case .linkedin:
            return .init(
                provider: "linkedin",
                strategy: "oauth_linkedin",
                name: "LinkedIn"
            )
        case .linkedin_oidc:
            return .init(
                provider: "linkedin_oidc",
                strategy: "oauth_linkedin_oidc",
                name: "LinkedIn"
            )
        case .dropbox:
            return .init(
                provider: "dropbox",
                strategy: "oauth_dropbox",
                name: "Dropbox"
            )
        case .atlassian:
            return .init(
                provider: "atlassian",
                strategy: "oauth_atlassian",
                name: "Atlassian"
            )
        case .bitbucket:
            return .init(
                provider: "bitbucket",
                strategy: "oauth_bitbucket",
                name: "Bitbucket"
            )
        case .microsoft:
            return .init(
                provider: "microsoft",
                strategy: "oauth_microsoft",
                name: "Microsoft"
            )
        case .notion:
            return .init(
                provider: "notion",
                strategy: "oauth_notion",
                name: "Notion"
            )
        case .apple:
            return .init(
                provider: "apple",
                strategy: "oauth_apple",
                name: "Apple"
            )
        case .line:
            return .init(
                provider: "line",
                strategy: "oauth_line",
                name: "LINE"
            )
        case .instagram:
            return .init(
                provider: "instagram",
                strategy: "oauth_instagram",
                name: "Instagram"
            )
        case .coinbase:
            return .init(
                provider: "coinbase",
                strategy: "oauth_coinbase",
                name: "Coinbase"
            )
        case .spotify:
            return .init(
                provider: "spotify",
                strategy: "oauth_spotify",
                name: "Spotify"
            )
        case .xero:
            return .init(
                provider: "xero",
                strategy: "oauth_xero",
                name: "Xero"
            )
        case .box:
            return .init(
                provider: "box",
                strategy: "oauth_box",
                name: "Box"
            )
        case .slack:
            return .init(
                provider: "slack",
                strategy: "oauth_slack",
                name: "Slack"
            )
        case .linear:
            return .init(
                provider: "linear",
                strategy: "oauth_linear",
                name: "Linear"
            )
        case .huggingFace:
            return .init(
                provider: "huggingface",
                strategy: "oauth_huggingface",
                name: "Hugging Face"
            )
        }
    }
}

extension OAuthProvider: Comparable {
    public static func <(lhs: Self, rhs: Self) -> Bool {
        return lhs.providerData.provider < rhs.providerData.provider
    }
}
