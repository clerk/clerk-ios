//
//  Clerk+Keychain.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

extension Clerk {
  /// Clears all Clerk-stored keychain items.
  ///
  /// This method deletes all keychain items that Clerk uses to store data, including:
  /// - Cached client data
  /// - Cached environment data
  /// - Device authentication token
  /// - Device token sync status
  /// - App Attest key ID
  ///
  /// This method uses a best-effort approach - errors are logged but don't prevent deletion
  /// of other items. Clerk must be configured before calling this method.
  ///
  /// **Note:** This only clears keychain items. It does not clear in-memory state such as
  /// the `client` and `environment` properties. To fully reset Clerk, you may also need
  /// to reconfigure the SDK.
  ///
  /// This method is useful for:
  /// - Debugging and testing
  /// - Privacy compliance (allowing users to clear all stored authentication data)
  /// - Resetting the SDK state
  ///
  /// - Example:
  /// ```swift
  /// Clerk.clearAllKeychainItems()
  /// ```
  @MainActor
  public static func clearAllKeychainItems() {
    let keychain = Clerk.shared.dependencies.keychain

    // Iterate over all keychain keys and delete each one
    for key in ClerkKeychainKey.allCases {
      do {
        try keychain.deleteItem(forKey: key.rawValue)
      } catch {
        // Log errors but continue deleting remaining items
        ClerkLogger.logError(
          error,
          message: "Failed to delete keychain item '\(key.rawValue)'. This is non-critical."
        )
      }
    }
  }
}
