#if os(iOS)

import ClerkKit
import SwiftUI

/// Per-provider OAuth configuration for additional scopes and prompts.
public struct OAuthProviderConfig: Sendable, Hashable {
  public let provider: OAuthProvider
  public let additionalScopes: [String]
  public let prompts: [OIDCPrompt]

  public init(provider: OAuthProvider, additionalScopes: [String] = [], prompts: [OIDCPrompt] = []) {
    self.provider = provider
    self.additionalScopes = additionalScopes
    self.prompts = prompts
  }
}

/// OAuth configuration for built-in connected account flows in ``UserProfileView``.
struct UserProfileOAuthConfiguration: Equatable {
  let configs: [OAuthProviderConfig]

  init(_ configs: [OAuthProviderConfig] = []) {
    self.configs = configs
  }

  func additionalScopes(for provider: OAuthProvider) -> [String] {
    configs.first { $0.provider == provider }?.additionalScopes ?? []
  }

  func prompts(for provider: OAuthProvider) -> [OIDCPrompt] {
    configs.first { $0.provider == provider }?.prompts ?? []
  }

  func requiresReauthorization(for account: ExternalAccount) -> Bool {
    let configuredScopes = Set(additionalScopes(for: account.oauthProvider))
    guard !configuredScopes.isEmpty else { return false }

    let approvedScopes = Set(account.approvedScopes.split(separator: " ").map(String.init))

    // If no approved scopes are reported, we can't determine if reauth is needed.
    guard !approvedScopes.isEmpty else { return false }
    return !configuredScopes.isSubset(of: approvedScopes)
  }
}

extension EnvironmentValues {
  var clerkUserProfileOAuthConfig: UserProfileOAuthConfiguration {
    get { self[UserProfileOAuthConfigKey.self] }
    set { self[UserProfileOAuthConfigKey.self] = newValue }
  }
}

private struct UserProfileOAuthConfigKey: EnvironmentKey {
  static let defaultValue = UserProfileOAuthConfiguration()
}

#endif
