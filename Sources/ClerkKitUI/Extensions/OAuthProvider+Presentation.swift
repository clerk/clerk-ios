import ClerkKit
import Foundation

extension OAuthProvider {
  init(strategy: String) {
    self.init(rawValue: strategy.hasPrefix("oauth_") ? String(strategy.dropFirst(6)) : strategy)
  }

  var strategy: String {
    "oauth_" + rawValue
  }

  var sortName: String {
    if case .unrecognized = self { return "\u{10FFFF}" }; return builtInName
  }

  private var builtInName: String {
    switch self {
    case .facebook: "Facebook"
    case .google: "Google"
    case .hubspot: "HubSpot"
    case .github: "GitHub"
    case .tiktok: "TikTok"
    case .gitlab: "GitLab"
    case .discord: "Discord"
    case .twitter: "Twitter"
    case .twitch: "Twitch"
    case .linkedin: "LinkedIn"
    case .linkedinOidc: "LinkedIn"
    case .dropbox: "Dropbox"
    case .atlassian: "Atlassian"
    case .bitbucket: "Bitbucket"
    case .microsoft: "Microsoft"
    case .notion: "Notion"
    case .apple: "Apple"
    case .line: "LINE"
    case .instagram: "Instagram"
    case .coinbase: "Coinbase"
    case .spotify: "Spotify"
    case .xero: "Xero"
    case .box: "Box"
    case .slack: "Slack"
    case .linear: "Linear"
    case .x: "X / Twitter"
    case .huggingface: "Hugging Face"
    case .vercel: "Vercel"
    case .enstall: "Enstall"
    case .unrecognized: ""
    }
  }

  func name(in environment: EnvironmentResource) -> String {
    if case .unrecognized = self { return settings(in: environment)?.name ?? builtInName }
    return builtInName
  }

  func iconImageUrl(in environment: EnvironmentResource) -> URL? {
    guard let url = settings(in: environment)?.logoUrl, !url.isEmptyTrimmed else { return nil }
    return URL(string: url)
  }

  private func settings(in environment: EnvironmentResource) -> OAuthProviderSettings? {
    environment.userSettings.social.compactMapValues { $0 }.values.first { $0.strategy.rawValue == strategy }
  }

  var supportsTintedIconMask: Bool {
    switch self { case .apple, .github, .vercel, .x: return true; default: return false }
  }
}
