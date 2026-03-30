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
    configs.filter { $0.provider == provider }.flatMap(\.additionalScopes)
  }

  func prompts(for provider: OAuthProvider) -> [OIDCPrompt] {
    configs.filter { $0.provider == provider }.flatMap(\.prompts)
  }

  func shouldOfferReconnect(for account: ExternalAccount) -> Bool {
    // Apple uses a native ID token flow and does not support redirect-based
    // reauthorization with additional scopes or prompts.
    guard account.oauthProvider != .apple else { return false }
    return requiresReauthorization(for: account) || !prompts(for: account.oauthProvider).isEmpty
  }

  func requiresReauthorization(for account: ExternalAccount) -> Bool {
    let configuredScopes = Set(additionalScopes(for: account.oauthProvider))
    guard !configuredScopes.isEmpty else { return false }

    let approvedScopes = Set(account.approvedScopes.split(separator: " ").map(String.init))

    // If no approved scopes are reported, assume the configured scopes
    // have not been granted so the user can request them via reconnect.
    guard !approvedScopes.isEmpty else { return true }
    return !configuredScopes.isSubset(of: approvedScopes)
  }
}

extension EnvironmentValues {
  @Entry var clerkUserProfileOAuthConfig = UserProfileOAuthConfiguration()
}

#endif
