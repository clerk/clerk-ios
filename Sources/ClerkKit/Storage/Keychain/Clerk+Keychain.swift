//
//  Clerk+Keychain.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

extension Clerk {
  private struct KeychainClearError: LocalizedError {
    let failedOperations: [String]

    var errorDescription: String? {
      "Unable to complete Clerk Keychain clear: \(failedOperations.joined(separator: ", "))."
    }
  }

  private struct PendingKeychainClear {
    let clerk: Clerk
    let dependencies: any Dependencies
    let clearOperation: Task<Void, Error>
    let identityClear: ClerkIdentityController.StorageClearContext
    let cacheManager: CacheManager?
  }

  private static let legacySharedCredentialKeys: [ClerkKeychainKey] = [
    .cachedClient,
    .cachedClientServerDate,
    .cachedEnvironment,
    .clerkDeviceToken,
    .sharedSessionSyncAuthState,
    .sharedSessionSyncAuthVersion,
    .sharedSessionSyncEnvironmentVersion,
    .sharedSessionSyncDeviceTokenState,
    .sharedSessionSyncDeviceTokenVersion,
  ]

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
  /// fingerprints so a stale Watch payload cannot restore cleared authentication. These
  /// coordination records do not contain a reusable device token, Client, or Environment.
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
  static func startKeychainClearIfNeeded(for clerk: Clerk) -> Task<Void, Error> {
    if let keychainClearTask = clerk.keychainClearTask {
      return keychainClearTask
    }

    let taskID = UUID()
    let pendingClear = beginKeychainClear(for: clerk)
    let task = Task { @MainActor in
      let result: Result<Void, any Error>
      do {
        try await finishKeychainClear(pendingClear)
        result = .success(())
      } catch {
        ClerkLogger.logError(error, message: "Failed to clear all Clerk Keychain items")
        result = .failure(error)
      }
      guard clerk.keychainClearTaskID == taskID else {
        return try result.get()
      }
      clerk.keychainClearTask = nil
      clerk.keychainClearTaskID = nil
      return try result.get()
    }
    clerk.keychainClearTaskID = taskID
    clerk.keychainClearTask = task
    return task
  }

  @MainActor
  private static func beginKeychainClear(for clerk: Clerk) -> PendingKeychainClear {
    let dependencies = clerk.dependencies
    let loggingConfiguration = ClerkLogger.Configuration(
      options: dependencies.configurationManager.options
    )
    let cacheManager = clerk.cacheManager
    cacheManager?.freezePersistence()
    let identityClear = clerk.identityController.beginStorageClear()
    let usesAtomicLocalIdentity = identityClear.usesAtomicLocalPersistence
    var initialFailedOperations: [String] = []
    if usesAtomicLocalIdentity {
      do {
        _ = try WatchSyncMetadataStore(keychain: dependencies.watchSyncKeychain)
          .saveClearTombstone()
      } catch {
        ClerkLogger.logError(error, message: "Failed to preserve the Watch clear watermark")
        initialFailedOperations.append("preserve Watch clear watermark")
      }
    }
    clerk.identityController.applyStorageClearToMemory(identityClear)
    let preservedKeys: Set<ClerkKeychainKey> = usesAtomicLocalIdentity
      ? [.sharedSessionSyncAdopted, .watchSyncMetadata]
      : [.sharedSessionSyncAdopted]
    clearAllKeychainItems(in: dependencies.appLocalKeychain, preserving: preservedKeys)
    clearAllKeychainItems(in: dependencies.identityKeychain, preserving: preservedKeys)
    clearKeychainItems(legacySharedCredentialKeys, in: dependencies.keychain)
    let clearOperation = clerk.identityController.enqueueLocalOperation { operationRevision in
      var failedOperations = initialFailedOperations
      do {
        try await clerk.identityController
          .deleteCapturedOwnerSlotAfterStorageClear(identityClear)
      } catch {
        ClerkLogger.logError(error, message: "Failed to withdraw Clerk's shared-session owner slot")
        failedOperations.append("withdraw shared-session owner slot")
      }

      await cacheManager?.drainFrozenPersistence()
      do {
        try clearAllKeychainItemsStrictly(
          in: dependencies.appLocalKeychain,
          preserving: preservedKeys,
          loggingConfiguration: loggingConfiguration
        )
      } catch {
        failedOperations.append("clear app-local Keychain")
      }
      do {
        try clearAllKeychainItemsStrictly(
          in: dependencies.identityKeychain,
          preserving: preservedKeys,
          loggingConfiguration: loggingConfiguration
        )
      } catch {
        failedOperations.append("clear identity Keychain")
      }
      do {
        try clearKeychainItemsStrictly(
          legacySharedCredentialKeys,
          in: dependencies.keychain,
          loggingConfiguration: loggingConfiguration
        )
      } catch {
        failedOperations.append("clear legacy shared credentials")
      }

      if let localIdentityIO = dependencies.atomicIdentityIO {
        do {
          _ = try await localIdentityIO.delete(operationRevision: operationRevision)
        } catch {
          ClerkLogger.logError(error, message: "Failed to delete Clerk's atomic identity")
          failedOperations.append("delete atomic identity")
        }
      }

      guard failedOperations.isEmpty else {
        throw KeychainClearError(failedOperations: failedOperations)
      }
    }
    return PendingKeychainClear(
      clerk: clerk,
      dependencies: dependencies,
      clearOperation: clearOperation,
      identityClear: identityClear,
      cacheManager: cacheManager
    )
  }

  @MainActor
  private static func finishKeychainClear(_ pendingClear: PendingKeychainClear) async throws {
    let result: Result<Void, any Error>
    let succeeded: Bool
    do {
      try await pendingClear.clearOperation.value
      result = .success(())
      succeeded = true
    } catch {
      result = .failure(error)
      succeeded = false
    }
    pendingClear.clerk.identityController.finishStorageClear(
      pendingClear.identityClear,
      succeeded: succeeded
    )
    if pendingClear.clerk.dependencies === pendingClear.dependencies,
       pendingClear.clerk.cacheManager === pendingClear.cacheManager
    {
      pendingClear.cacheManager?.resumePersistence()
    }
    try result.get()
  }

  @MainActor
  static func clearAllKeychainItems(
    in keychain: any KeychainStorage,
    preserving preservedKeys: Set<ClerkKeychainKey> = [.sharedSessionSyncAdopted]
  ) {
    // Iterate over all keychain keys and delete each one
    for key in ClerkKeychainKey.allCases where !preservedKeys.contains(key) {
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
  private static func clearKeychainItems(
    _ keys: [ClerkKeychainKey],
    in keychain: any KeychainStorage
  ) {
    for key in keys {
      do {
        try keychain.deleteItem(forKey: key.rawValue)
      } catch {
        ClerkLogger.logError(
          error,
          message: "Failed to delete legacy shared Keychain item '\(key.rawValue)'."
        )
      }
    }
  }

  @MainActor
  private static func clearKeychainItemsStrictly(
    _ keys: [ClerkKeychainKey],
    in keychain: any KeychainStorage,
    loggingConfiguration: ClerkLogger.Configuration? = nil
  ) throws {
    var failures: [String] = []
    for key in keys {
      do {
        try keychain.deleteItem(forKey: key.rawValue)
      } catch {
        failures.append(key.rawValue)
        ClerkLogger.logError(
          error,
          message: "Failed to delete legacy shared Keychain item '\(key.rawValue)'.",
          configuration: loggingConfiguration
        )
      }
    }
    guard failures.isEmpty else {
      throw KeychainClearError(failedOperations: failures)
    }
  }

  @MainActor
  static func clearAllKeychainItemsStrictly(
    in keychain: any KeychainStorage,
    preserving preservedKeys: Set<ClerkKeychainKey> = [.sharedSessionSyncAdopted],
    loggingConfiguration: ClerkLogger.Configuration? = nil
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
          configuration: loggingConfiguration
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
  static func clearLocalClerkStorageStrictly(
    in dependencies: any Dependencies,
    deleteSharedSessionOwnerSlot: Bool = true
  ) async throws {
    let loggingConfiguration = ClerkLogger.Configuration(
      options: dependencies.configurationManager.options
    )
    _ = try WatchSyncMetadataStore(keychain: dependencies.watchSyncKeychain)
      .saveClearTombstone()
    let preservedKeys: Set<ClerkKeychainKey> = [
      .sharedSessionSyncAdopted,
      .watchSyncMetadata,
    ]
    if deleteSharedSessionOwnerSlot {
      try await SharedSessionOwnerSlotCleanup.deleteIfConfigured(in: dependencies)
    }

    try clearAllKeychainItemsStrictly(
      in: dependencies.appLocalKeychain,
      preserving: preservedKeys,
      loggingConfiguration: loggingConfiguration
    )
    try clearAllKeychainItemsStrictly(
      in: dependencies.identityKeychain,
      preserving: preservedKeys,
      loggingConfiguration: loggingConfiguration
    )
    try clearKeychainItemsStrictly(
      legacySharedCredentialKeys,
      in: dependencies.keychain,
      loggingConfiguration: loggingConfiguration
    )
    if let localIdentityIO = dependencies.atomicIdentityIO {
      try await localIdentityIO.delete()
    } else {
      try dependencies.atomicIdentityStore?.delete()
    }
  }
}
