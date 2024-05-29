//
//  ExternalProvider.swift
//
//
//  Created by Mike Pitre on 10/18/23.
//

import Foundation

/// The available external authentication providers.
public enum ExternalProvider: Codable, CaseIterable, Identifiable, Sendable, Equatable {
    public var id: Self { self }
    
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
    
    init?(strategy: String) {
        if let provider = Self.allCases.first(where: { $0.info.strategy == strategy }) {
            self = provider
        } else {
            return nil
        }
    }
    
    public struct Info {
        let provider: String
        let strategy: String
        public let name: String
        let docsUrl: String
    }
    
    public var info: Info {
        switch self {
        case .facebook:
            return .init(
                provider: "facebook",
                strategy: "oauth_facebook",
                name: "Facebook",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-facebook"
            )
        case .google:
            return .init(
                provider: "google",
                strategy: "oauth_google",
                name: "Google",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-google"
            )
        case .hubspot:
            return .init(
                provider: "hubspot",
                strategy: "oauth_hubspot",
                name: "HubSpot",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-hubspot"
            )
        case .github:
            return .init(
                provider: "github",
                strategy: "oauth_github",
                name: "GitHub",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-github"
            )
        case .tiktok:
            return .init(
                provider: "tiktok",
                strategy: "oauth_tiktok",
                name: "TikTok",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-tiktok"
            )
        case .gitlab:
            return .init(
                provider: "gitlab",
                strategy: "oauth_gitlab",
                name: "GitLab",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-gitlab"
            )
        case .discord:
            return .init(
                provider: "discord",
                strategy: "oauth_discord",
                name: "Discord",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-discord"
            )
        case .twitter:
            return .init(
                provider: "twitter",
                strategy: "oauth_twitter",
                name: "Twitter",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-twitter"
            )
        case .twitch:
            return .init(
                provider: "twitch",
                strategy: "oauth_twitch",
                name: "Twitch",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-twitch"
            )
        case .linkedin:
            return .init(
                provider: "linkedin",
                strategy: "oauth_linkedin",
                name: "LinkedIn",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-linkedin"
            )
        case .linkedin_oidc:
            return .init(
                provider: "linkedin_oidc",
                strategy: "oauth_linkedin_oidc",
                name: "LinkedIn",
                docsUrl: "https://clerk.com/docs/authentication/social-connections/linkedin-oidc"
            )
        case .dropbox:
            return .init(
                provider: "dropbox",
                strategy: "oauth_dropbox",
                name: "Dropbox",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-dropbox"
            )
        case .atlassian:
            return .init(
                provider: "atlassian",
                strategy: "oauth_atlassian",
                name: "Atlassian",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-atlassian"
            )
        case .bitbucket:
            return .init(
                provider: "bitbucket",
                strategy: "oauth_bitbucket",
                name: "Bitbucket",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-bitbucket"
            )
        case .microsoft:
            return .init(
                provider: "microsoft",
                strategy: "oauth_microsoft",
                name: "Microsoft",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-microsoft"
            )
        case .notion:
            return .init(
                provider: "notion",
                strategy: "oauth_notion",
                name: "Notion",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-notion"
            )
        case .apple:
            return .init(
                provider: "apple",
                strategy: "oauth_apple",
                name: "Apple",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-apple"
            )
        case .line:
            return .init(
                provider: "line",
                strategy: "oauth_line",
                name: "LINE",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-line"
            )
        case .instagram:
            return .init(
                provider: "instagram",
                strategy: "oauth_instagram",
                name: "Instagram",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-instagram"
            )
        case .coinbase:
            return .init(
                provider: "coinbase",
                strategy: "oauth_coinbase",
                name: "Coinbase",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-coinbase"
            )
        case .spotify:
            return .init(
                provider: "spotify",
                strategy: "oauth_spotify",
                name: "Spotify",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-spotify"
            )
        case .xero:
            return .init(
                provider: "xero",
                strategy: "oauth_xero",
                name: "Xero",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-xero"
            )
        case .box:
            return .init(
                provider: "box",
                strategy: "oauth_box",
                name: "Box",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-box"
            )
        case .slack:
            return .init(
                provider: "slack",
                strategy: "oauth_slack",
                name: "Slack",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-slack"
            )
        case .linear:
            return .init(
                provider: "linear",
                strategy: "oauth_linear",
                name: "Linear",
                docsUrl: "https://clerk.com/docs/authentication/social-connection-with-linear"
            )
        }
    }
    
    var hasDarkModeVariant: Bool {
        switch self {
        case .apple:
            return true
        default:
            return false
        }
    }
    
    public func iconImageUrl(darkMode: Bool = false) -> URL? {
        var iconName = info.provider
        if darkMode && hasDarkModeVariant { iconName += "-dark" }
        return URL(string: "https://img.clerk.com/static/\(iconName).png")
    }
}

extension ExternalProvider: Comparable {
    public static func <(lhs: Self, rhs: Self) -> Bool {
        return lhs.info.name < rhs.info.name
    }
}
