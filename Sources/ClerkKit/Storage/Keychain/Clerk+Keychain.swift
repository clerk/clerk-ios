//
//  Clerk+Keychain.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

extension Clerk {
  /// Clears Clerk authentication and private cached data from Keychain.
  ///
  /// This method deletes Clerk-stored authentication and application data, including:
  /// - Cached client data
  /// - Cached environment data
  /// - Device authentication token
  /// - Device token sync status
  /// - App Attest key ID
  ///
  /// Clerk retains the non-secret shared-session adoption marker so disabling sync cannot
  /// resurrect legacy shared credentials. After atomic shared-session adoption, Clerk also
  /// retains Watch ordering metadata containing only transition state, versions, and
  /// fingerprints so a stale Watch payload cannot restore cleared authentication. While an
  /// owner slot is being withdrawn, Clerk retains a durable recovery intent so an interrupted
  /// clear is completed before the next configuration hydrates identity. These coordination
  /// records do not contain a reusable device token, Client, or Environment.
  ///
  /// This source-compatible method starts a best-effort asynchronous clear and returns after
  /// synchronously clearing the legacy keys it can safely reach. Use
  /// ``clearAllKeychainItemsAndWait()`` when durable completion must be confirmed.
  ///
  /// **Note:** This ordinarily clears only Keychain items. After shared-session adoption,
  /// Clerk also clears the live token/client identity coherently so requests cannot observe
  /// a tokenless active client while the calling app's owner slot is being withdrawn.
  ///
  /// This method is useful for:
  /// - Debugging and testing
  /// - Privacy compliance (allowing users to clear stored authentication and user data)
  /// - Resetting the SDK state
  ///
  /// - Example:
  /// ```swift
  /// Clerk.clearAllKeychainItems()
  /// ```
  @MainActor
  public static func clearAllKeychainItems() {
    _ = startKeychainClearIfNeeded(for: Clerk.shared)
  }

  /// Clears Clerk authentication and private cached data and waits until this app's
  /// shared-session owner slot has been withdrawn. Non-secret coordination markers are
  /// retained as described by ``clearAllKeychainItems()``.
  ///
  /// - Throws: An error identifying cleanup boundaries that could not be durably cleared.
  @MainActor
  public static func clearAllKeychainItemsAndWait() async throws {
    try await Clerk.shared.clearAllKeychainItemsAndWait()
  }

  @MainActor
  func clearAllKeychainItemsAndWait() async throws {
    try await Self.startKeychainClearIfNeeded(for: self).value
  }

  @MainActor
  static func clearAllKeychainItems(
    in keychain: any KeychainStorage,
    preserving preservedKeys: Set<ClerkKeychainKey> = [.sharedSessionSyncAdopted],
    configuration: ClerkLogger.Configuration? = nil
  ) {
    // Iterate over all keychain keys and delete each one
    for key in ClerkKeychainKey.allCases where !preservedKeys.contains(key) {
      do {
        try keychain.deleteItem(forKey: key.rawValue)
      } catch {
        // Log errors but continue deleting remaining items
        ClerkLogger.logError(
          error,
          message: "Failed to delete keychain item '\(key.rawValue)'. This is non-critical.",
          configuration: configuration
        )
      }
    }
  }

  @MainActor
  static func clearAllKeychainItemsStrictly(
    in keychain: any KeychainStorage,
    preserving preservedKeys: Set<ClerkKeychainKey> = [.sharedSessionSyncAdopted],
    configuration: ClerkLogger.Configuration? = nil
  ) throws {
    var failures: [String] = []

    for key in ClerkKeychainKey.allCases where !preservedKeys.contains(key) {
      do {
        try keychain.deleteItem(forKey: key.rawValue)
      } catch {
        failures.append(key.rawValue)
        ClerkLogger.logError(
          error,
          message: "Failed to delete keychain item '\(key.rawValue)' during Clerk reconfiguration.",
          configuration: configuration
        )
      }
    }

    guard failures.isEmpty else {
      throw ClerkClientError(
        message: "Unable to clear Clerk keychain items during reconfiguration."
      )
    }
  }
}
