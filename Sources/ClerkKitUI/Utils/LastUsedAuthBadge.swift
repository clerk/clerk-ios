//
//  LastUsedAuthBadge.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import Foundation

@MainActor
enum LastUsedAuthBadge {
  /// Determines if an authentication badge should be shown for the given strategies.
  ///
  /// Returns true when:
  /// - The last authentication strategy is in the provided array, AND
  /// - Multiple identification strategies are available
  ///
  /// This is used to show visual indicators (badges) for the most recently used
  /// authentication method when multiple sign-in options are available.
  ///
  /// Use the static strategy arrays on `FactorStrategy` for common groupings:
  /// - `.emailStrategies` - All strategies that use email
  /// - `.phoneStrategies` - All strategies that use phone
  /// - `.usernameStrategies` - All strategies that use username
  ///
  /// - Parameter strategies: The array of strategies to check against
  /// - Returns: True if the badge should be shown
  static func shouldShow(for strategies: [FactorStrategy]) -> Bool {
    guard let lastAuth = Clerk.shared.client?.lastAuthenticationStrategy,
          (Clerk.shared.environment?.totalEnabledAuthMethods ?? 0) > 1,
          Clerk.shared.environment?.canShowLastUsedBadge ?? false
    else {
      return false
    }
    return strategies.contains(lastAuth)
  }

  /// Convenience overload for checking a single strategy.
  ///
  /// - Parameter strategy: The authentication strategy to check
  /// - Returns: True if the badge should be shown for this strategy
  static func shouldShow(for strategy: FactorStrategy) -> Bool {
    shouldShow(for: [strategy])
  }
}

#endif
