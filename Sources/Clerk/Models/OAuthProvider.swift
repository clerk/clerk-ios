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
    
    /// A type that represents a custom OAuth strategy.
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
    
    public var id: String { providerData.strategy }
    
    public init(strategy: String) {
        if let provider = Self.allCases.first(where: { $0.providerData.strategy == strategy }) {
            self = provider
        } else {
            self = .custom(strategy)
        }
    }
    
    /// The name of the OAuth provider (e.g. "Google")
    @MainActor
    public var name: String {
        switch self {
        case .custom(let strategy):
            if let socialConfig = Clerk.shared.environment?.userSettings.social.first(where: { socialConfig in
                socialConfig.value.strategy == strategy
            }) {
                return socialConfig.value.name
            }
            
            // Sensible fallback, but name value should be on the social config
            return OAuthProvider.providerFromStrategy(strategy).replacingOccurrences(of: "_", with: " ")
        default:
            return providerData.name
        }
    }
    
    /// The String strategy for the provider. (e.g. "oauth_google" or "oauth_custom_google")
    public var strategy: String {
        switch self {
        case .custom(let strategy):
            return strategy
        default:
            return providerData.strategy
        }
    }
    
    /// The icon of the provider.
    ///
    /// - Parameters:
    ///     - darkMode: Will return the dark mode variant of the image. Does not apply to custom providers.
    @MainActor
    public func iconImageUrl(darkMode: Bool = false) -> URL? {
        switch self {
        case .custom(let strategy):
            if let socialConfig = Clerk.shared.environment?.userSettings.social.first(where: { socialConfig in
                socialConfig.value.strategy == strategy && socialConfig.value.logoUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }) {
                return URL(string: socialConfig.value.logoUrl ?? "")
            }
            
            return nil
            
        default:
                
            if let socialConfig = Clerk.shared.environment?.userSettings.social.first(where: { socialConfig in
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
        public let strategy: String
        public let name: String
        public var provider: String {
            OAuthProvider.providerFromStrategy(strategy)
        }
    }
        
    private var providerData: OAuthProviderData {
        switch self {
        case .custom(let strategy):
            return .init(
                strategy: strategy,
                name: ""
            )
        case .facebook:
            return .init(
                strategy: "oauth_facebook",
                name: "Facebook"
            )
        case .google:
            return .init(
                strategy: "oauth_google",
                name: "Google"
            )
        case .hubspot:
            return .init(
                strategy: "oauth_hubspot",
                name: "HubSpot"
            )
        case .github:
            return .init(
                strategy: "oauth_github",
                name: "GitHub"
            )
        case .tiktok:
            return .init(
                strategy: "oauth_tiktok",
                name: "TikTok"
            )
        case .gitlab:
            return .init(
                strategy: "oauth_gitlab",
                name: "GitLab"
            )
        case .discord:
            return .init(
                strategy: "oauth_discord",
                name: "Discord"
            )
        case .twitter:
            return .init(
                strategy: "oauth_twitter",
                name: "Twitter"
            )
        case .twitch:
            return .init(
                strategy: "oauth_twitch",
                name: "Twitch"
            )
        case .linkedin:
            return .init(
                strategy: "oauth_linkedin",
                name: "LinkedIn"
            )
        case .linkedin_oidc:
            return .init(
                strategy: "oauth_linkedin_oidc",
                name: "LinkedIn"
            )
        case .dropbox:
            return .init(
                strategy: "oauth_dropbox",
                name: "Dropbox"
            )
        case .atlassian:
            return .init(
                strategy: "oauth_atlassian",
                name: "Atlassian"
            )
        case .bitbucket:
            return .init(
                strategy: "oauth_bitbucket",
                name: "Bitbucket"
            )
        case .microsoft:
            return .init(
                strategy: "oauth_microsoft",
                name: "Microsoft"
            )
        case .notion:
            return .init(
                strategy: "oauth_notion",
                name: "Notion"
            )
        case .apple:
            return .init(
                strategy: "oauth_apple",
                name: "Apple"
            )
        case .line:
            return .init(
                strategy: "oauth_line",
                name: "LINE"
            )
        case .instagram:
            return .init(
                strategy: "oauth_instagram",
                name: "Instagram"
            )
        case .coinbase:
            return .init(
                strategy: "oauth_coinbase",
                name: "Coinbase"
            )
        case .spotify:
            return .init(
                strategy: "oauth_spotify",
                name: "Spotify"
            )
        case .xero:
            return .init(
                strategy: "oauth_xero",
                name: "Xero"
            )
        case .box:
            return .init(
                strategy: "oauth_box",
                name: "Box"
            )
        case .slack:
            return .init(
                strategy: "oauth_slack",
                name: "Slack"
            )
        case .linear:
            return .init(
                strategy: "oauth_linear",
                name: "Linear"
            )
        case .huggingFace:
            return .init(
                strategy: "oauth_huggingface",
                name: "Hugging Face"
            )
        }
    }
    
    private static func providerFromStrategy(_ strategy: String) -> String {
        let standardRegex = Regex {
            "oauth_"
            Capture {
                OneOrMore(.any)
            }
        }
        
        let customRegex = Regex {
            "oauth_custom_"
            Capture {
                OneOrMore(.any)
            }
        }
        
        var provider: String
        
        // custom must come before standard because it is more stringent
        if let providerName = strategy.firstMatch(of: customRegex)?.output.1 ?? strategy.firstMatch(of: standardRegex)?.output.1 {
            provider = String(providerName)
        } else {
            provider = ""
        }
        
        return provider
    }
}

extension OAuthProvider: Comparable {
    public static func <(lhs: Self, rhs: Self) -> Bool {
        return lhs.providerData.provider < rhs.providerData.provider
    }
}
