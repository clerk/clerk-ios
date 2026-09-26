//
//  Clerk+Keychain.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

extension Clerk {
  private struct KeychainClearError: LocalizedError {
    let failedItems: [String]

    var errorDescription: String? {
      "Unable to complete Clerk Keychain clear: \(failedItems.joined(separator: ", "))."
    }
  }

  /// Non-secret markers kept across clears: where this app's private state lives, that its
  /// identity was already migrated, and how many clears it has seen (so Watch state from before
  /// the clear is rejected).
  static let preservedKeychainKeys: Set<ClerkKeychainKey> = [
    .sharedSessionSyncAdopted,
    .identityMigrated,
    .watchSyncClearGeneration,
  ]

  /// Keys the app clears leave for their identity step. The identity store removes the identity where
  /// it lives; a record elsewhere, such as in the access group of an app with sync off, belongs to
  /// other apps.
  private static let keysPreservedAlongsideIdentity = preservedKeychainKeys.union([.identity])

  /// Clears Clerk authentication and private cached data from Keychain.
  ///
  /// This method deletes Clerk-stored authentication and application data, including:
  /// - The device authentication token and cached client
  /// - Cached environment data
  /// - App Attest key ID
  ///
  /// It also signs out the in-memory client. With shared-session sync, the identity is
  /// shared, so this signs out every app sharing it.
  ///
  /// Clerk keeps non-secret markers that record where this app's private state lives, that
  /// its storage was migrated, and how many clears it has seen. They contain no token or Client.
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
    guard !runtimeReconfigurationIsInProgress else {
      Task { @MainActor in
        await waitForRuntimeReconfigurationIfNeeded()
        clearAllKeychainItems()
      }
      return
    }
    do {
      try Clerk.shared.clearKeychainItems()
    } catch {
      ClerkLogger.logError(error, message: "Failed to clear all Clerk Keychain items")
    }
  }

  /// Clears Clerk authentication and private cached data, as described by
  /// ``clearAllKeychainItems()``, and reports whether every item was deleted.
  ///
  /// - Throws: An error naming the items that could not be deleted.
  @MainActor
  public static func clearAllKeychainItemsAndWait() async throws {
    await waitForRuntimeReconfigurationIfNeeded()
    try Clerk.shared.clearKeychainItems()
  }

  @MainActor
  func clearKeychainItems() throws {
    let configuration = ClerkLogger.Configuration(options: options)
    var failures = Self.clearIdentityAndMarkClear(in: dependencies, configuration: configuration) {
      try identityController.clearIdentity()
    }
    failures += Self.clearAllKeychainItemsCollectingFailures(
      in: dependencies.appLocalKeychain,
      preserving: Self.keysPreservedAlongsideIdentity,
      configuration: configuration
    )
    failures += Self.clearAllKeychainItemsCollectingFailures(
      in: dependencies.keychain,
      preserving: Self.keysPreservedAlongsideIdentity,
      configuration: configuration
    )
    guard failures.isEmpty else {
      throw KeychainClearError(failedItems: failures)
    }
  }

  /// Clears Clerk data before installing a new configuration, logging with that configuration's options.
  ///
  /// An identity stored in an access group belongs to every app and extension in the group, so it is left for them.
  @MainActor
  static func clearLocalClerkStorageStrictly(in dependencies: any Dependencies) throws {
    let configuration = ClerkLogger.Configuration(options: dependencies.configurationManager.options)
    let keepsIdentity = dependencies.identityIsInAccessGroup
    var failures = clearIdentityAndMarkClear(in: dependencies, configuration: configuration) {
      if !keepsIdentity {
        try dependencies.identityStore.delete()
      }
    }
    failures += clearAllKeychainItemsCollectingFailures(
      in: dependencies.appLocalKeychain,
      preserving: keysPreservedAlongsideIdentity,
      configuration: configuration
    )
    failures += clearAllKeychainItemsCollectingFailures(
      in: dependencies.keychain,
      preserving: keysPreservedAlongsideIdentity,
      configuration: configuration
    )
    guard failures.isEmpty else {
      throw reconfigurationClearError
    }
  }

  /// Deletes every Clerk Keychain item in `keychain` except `preservedKeys`, logging failures.
  @MainActor
  static func clearAllKeychainItems(
    in keychain: any KeychainStorage,
    preserving preservedKeys: Set<ClerkKeychainKey> = preservedKeychainKeys
  ) {
    _ = clearAllKeychainItemsCollectingFailures(in: keychain, preserving: preservedKeys)
  }

  /// Deletes every Clerk Keychain item in `keychain` except `preservedKeys`.
  @MainActor
  static func clearAllKeychainItemsStrictly(
    in keychain: any KeychainStorage,
    preserving preservedKeys: Set<ClerkKeychainKey> = preservedKeychainKeys
  ) throws {
    guard clearAllKeychainItemsCollectingFailures(in: keychain, preserving: preservedKeys).isEmpty else {
      throw reconfigurationClearError
    }
  }

  private static var reconfigurationClearError: ClerkClientError {
    ClerkClientError(
      message: "Unable to clear Clerk keychain items during reconfiguration.",
      localizationBundle: .module
    )
  }

  /// Records the clear for Watch sync and for an unfinished identity migration, then removes the
  /// identity. Returns the items that failed.
  @MainActor
  private static func clearIdentityAndMarkClear(
    in dependencies: any Dependencies,
    configuration: ClerkLogger.Configuration,
    removeIdentity: () throws -> Void
  ) -> [String] {
    var failures: [String] = []
    do {
      try WatchSyncClearMarker.record(in: dependencies.watchSyncKeychain)
    } catch {
      failures.append(ClerkKeychainKey.watchSyncClearGeneration.rawValue)
      ClerkLogger.logError(error, message: "Failed to record the Watch clear", configuration: configuration)
    }
    do {
      try ClerkIdentityMigration.recordClear(in: dependencies.identityMigrationMarkerKeychain)
    } catch {
      failures.append(ClerkKeychainKey.identityMigrated.rawValue)
      ClerkLogger.logError(error, message: "Failed to record the clear for the identity migration", configuration: configuration)
    }
    do {
      try removeIdentity()
    } catch {
      failures.append(dependencies.identityStore.key)
      ClerkLogger.logError(error, message: "Failed to delete the Clerk identity", configuration: configuration)
    }
    return failures
  }

  @MainActor
  private static func clearAllKeychainItemsCollectingFailures(
    in keychain: any KeychainStorage,
    preserving preservedKeys: Set<ClerkKeychainKey> = preservedKeychainKeys,
    configuration: ClerkLogger.Configuration? = nil
  ) -> [String] {
    var failures: [String] = []
    var biometricCredentialDeletionFailed = false

    do {
      try BiometricCredentialLocalStore(keychain: keychain)
        .deleteAllLocalCredentials(keyManager: BiometricCredentialKeyManager())
    } catch {
      biometricCredentialDeletionFailed = true
      failures.append(ClerkKeychainKey.biometricCredentials.rawValue)
      ClerkLogger.logError(error, message: "Failed to delete biometric local credentials.", configuration: configuration)
    }

    for key in ClerkKeychainKey.allCases where !preservedKeys.contains(key) {
      guard key != .biometricCredentials || !biometricCredentialDeletionFailed else {
        continue
      }
      do {
        try keychain.deleteItem(forKey: key.rawValue)
      } catch {
        failures.append(key.rawValue)
        ClerkLogger.logError(
          error,
          message: "Failed to delete keychain item '\(key.rawValue)'.",
          configuration: configuration
        )
      }
    }
    return failures
  }
}
