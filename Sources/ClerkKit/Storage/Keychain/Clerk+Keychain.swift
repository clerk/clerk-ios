//
//  Clerk+Keychain.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

struct ClerkKeychainSnapshot {
  struct Item {
    let keychain: any KeychainStorage
    let key: String
    let data: Data?
  }

  let items: [Item]

  func restore() throws {
    var didFail = false

    for item in items {
      do {
        let currentData = try item.keychain.data(forKey: item.key)
        guard currentData != item.data else { continue }

        if let data = item.data {
          try item.keychain.set(data, forKey: item.key)
        } else {
          try item.keychain.deleteItem(forKey: item.key)
        }
      } catch {
        didFail = true
        ClerkLogger.logError(
          error,
          message: "Failed to restore keychain item '\(item.key)' after Clerk reconfiguration failed."
        )
      }
    }

    guard !didFail else {
      throw ClerkClientError(
        message: "Clerk reconfiguration failed and the previous keychain state could not be fully restored."
      )
    }
  }
}

extension Clerk {
  /// Clears Clerk authentication and cache items from the keychain.
  ///
  /// This method deletes Clerk data including:
  /// - Cached client data
  /// - Cached environment data
  /// - Device authentication token
  /// - Device token sync status
  /// - App Attest key ID
  ///
  /// Clerk preserves its internal shared-session adoption marker so subsequent
  /// writes continue using the same app-local storage after the reset.
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
    clearAllKeychainItems(in: Clerk.shared)
  }

  @MainActor
  static func clearAllKeychainItems(in clerk: Clerk) {
    let dependencies = clerk.dependencies
    clearSharedSessionEnvelope(in: dependencies)
    for keychain in identityKeychains(in: dependencies) {
      clearAllKeychainItems(in: keychain)
    }
    clerk.hardFenceClientResponses()
    clerk.sharedSessionSyncCoordinator?
      .invalidateCachedIdentityAfterKeychainClear()
  }

  @MainActor
  static func clearAllKeychainItems(in keychain: any KeychainStorage) {
    // Iterate over all keychain keys and delete each one
    for key in ClerkKeychainKey.allCases where key != .sharedSessionSyncAdopted {
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

  @MainActor
  static func clearAllKeychainItemsStrictly(in keychain: any KeychainStorage) throws {
    var failures: [String] = []

    for key in ClerkKeychainKey.allCases where key != .sharedSessionSyncAdopted {
      do {
        try keychain.deleteItem(forKey: key.rawValue)
      } catch {
        failures.append(key.rawValue)
        ClerkLogger.logError(
          error,
          message: "Failed to delete keychain item '\(key.rawValue)' during Clerk reconfiguration."
        )
      }
    }

    guard failures.isEmpty else {
      throw ClerkClientError(
        message: "Unable to clear Clerk keychain items during reconfiguration."
      )
    }
  }

  @MainActor
  static func clearAllKeychainItemsStrictly(in dependencies: any Dependencies) throws {
    var didFail = false

    do {
      try sharedSessionStore(in: dependencies).delete()
    } catch {
      didFail = true
      ClerkLogger.logError(
        error,
        message: "Failed to delete the shared Clerk auth envelope during reconfiguration."
      )
    }

    for keychain in identityKeychains(in: dependencies) {
      do {
        try clearAllKeychainItemsStrictly(in: keychain)
      } catch {
        didFail = true
      }
    }

    guard !didFail else {
      throw ClerkClientError(
        message: "Unable to clear Clerk keychain items during reconfiguration."
      )
    }
  }

  @MainActor
  static func captureKeychainSnapshot(
    in dependencies: [any Dependencies]
  ) throws -> ClerkKeychainSnapshot {
    var items: [ClerkKeychainSnapshot.Item] = []

    for dependencies in dependencies {
      for keychain in identityKeychains(in: dependencies) {
        for key in ClerkKeychainKey.allCases {
          try items.append(
            ClerkKeychainSnapshot.Item(
              keychain: keychain,
              key: key.rawValue,
              data: keychain.data(forKey: key.rawValue)
            )
          )
        }
      }
    }

    return ClerkKeychainSnapshot(items: items)
  }

  @MainActor
  private static func clearSharedSessionEnvelope(in dependencies: any Dependencies) {
    do {
      try sharedSessionStore(in: dependencies).delete()
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to delete the shared Clerk auth envelope. This is non-critical."
      )
    }
  }

  private static func sharedSessionStore(
    in dependencies: any Dependencies
  ) -> SharedSessionSyncStore {
    SharedSessionSyncStore(
      keychain: dependencies.keychain,
      namespace: SharedSessionSyncNamespace(
        frontendApiUrl: dependencies.configurationManager.frontendApiUrl
      )
    )
  }

  private static func identityKeychains(
    in dependencies: any Dependencies
  ) -> [any KeychainStorage] {
    var keychains: [any KeychainStorage] = [
      dependencies.keychain,
      dependencies.appLocalKeychain,
      dependencies.identityKeychain,
    ]
    if let legacyAppLocalKeychain = dependencies.legacyAppLocalKeychain {
      keychains.append(legacyAppLocalKeychain)
    }
    return keychains
  }
}
