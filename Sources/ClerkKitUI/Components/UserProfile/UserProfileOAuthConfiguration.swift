#if os(iOS)

import ClerkKit
import SwiftUI

/// OAuth configuration for built-in connected account flows in ``UserProfileView``.
public struct UserProfileOAuthConfiguration: Sendable, Equatable {
  /// Additional OAuth scopes to request per provider for connected account flows.
  public var additionalScopes: [OAuthScopes]

  /// OIDC prompts to request per provider for connected account flows.
  public var prompts: [OAuthPrompts]

  /// Creates a new user profile OAuth configuration.
  public init(
    additionalScopes: [OAuthScopes] = [],
    prompts: [OAuthPrompts] = []
  ) {
    self.additionalScopes = additionalScopes
    self.prompts = prompts
  }

  func additionalScopes(for provider: OAuthProvider) -> [String] {
    additionalScopes.first { $0.provider == provider }?.scopes ?? []
  }

  func prompts(for provider: OAuthProvider) -> [OIDCPrompt] {
    prompts.first { $0.provider == provider }?.prompts ?? []
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

/// Additional OAuth scopes to request for a specific provider.
public struct OAuthScopes: Sendable, Hashable {
  public let provider: OAuthProvider
  public let scopes: [String]

  public init(provider: OAuthProvider, scopes: [String]) {
    self.provider = provider
    self.scopes = scopes
  }
}

/// OIDC prompts to request for a specific provider.
public struct OAuthPrompts: Sendable, Hashable {
  public let provider: OAuthProvider
  public let prompts: [OIDCPrompt]

  public init(provider: OAuthProvider, prompts: [OIDCPrompt]) {
    self.provider = provider
    self.prompts = prompts
  }
}

extension EnvironmentValues {
  var clerkUserProfileOAuthConfiguration: UserProfileOAuthConfiguration {
    get { self[UserProfileOAuthConfigurationKey.self] }
    set { self[UserProfileOAuthConfigurationKey.self] = newValue }
  }
}

private struct UserProfileOAuthConfigurationKey: EnvironmentKey {
  static let defaultValue = UserProfileOAuthConfiguration()
}

#endif
