#if os(iOS) || os(macOS)

import ClerkKit
import Foundation

extension Clerk.Environment {
  var authenticatableOAuthProviders: [OAuthProvider] {
    authenticatableSocialProviders
      .map { OAuthProvider(strategy: $0.strategy) }
      .sorted()
  }

  var enabledOAuthProviders: [OAuthProvider] {
    allSocialProviders
      .map { OAuthProvider(strategy: $0.strategy) }
      .sorted()
  }

  var totalEnabledFirstFactorMethods: Int {
    let identifierCount = [attributes.emailAddress, attributes.phoneNumber, attributes.username]
      .filter { $0.enabled && $0.usedForFirstFactor }
      .count
    return identifierCount + authenticatableOAuthProviders.count
  }

  var mutliSessionModeIsEnabled: Bool {
    multiSessionModeIsEnabled
  }

  private var attributes: Attributes {
    userSettings.attributes
  }
}

#endif
