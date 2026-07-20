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
    let sharedTransportWithdrawn: Bool

    init(
      failedOperations: [String],
      sharedTransportWithdrawn: Bool = false
    ) {
      self.failedOperations = failedOperations
      self.sharedTransportWithdrawn = sharedTransportWithdrawn
    }

    var errorDescription: String? {
      "Unable to complete Clerk Keychain clear: \(failedOperations.joined(separator: ", "))."
    }
  }

  private struct KeychainClearResult {
    let sharedTransportWithdrawn: Bool
  }

  private struct PendingKeychainClear {
    let clerk: Clerk
    let dependencies: any Dependencies
    let clearOperation: Task<KeychainClearResult, Error>
    let identityClear: ClerkIdentityController.StorageClearContext
    let cacheManager: CacheManager?
    let loggingConfiguration: ClerkLogger.Configuration
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
        ClerkLogger.logError(
          error,
          message: "Failed to clear all Clerk Keychain items",
          configuration: pendingClear.loggingConfiguration
        )
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
    let loggingConfiguration = ClerkLogger.Configuration(options: clerk.options)
    let cacheManager = clerk.cacheManager
    cacheManager?.freezePersistence()
    let identityClear = clerk.identityController.beginStorageClear()
    let usesAtomicLocalIdentity = identityClear.usesAtomicLocalPersistence
    var initialFailedOperations = preserveWatchClearWatermarkIfNeeded(
      using: dependencies,
      usesAtomicLocalIdentity: usesAtomicLocalIdentity,
      loggingConfiguration: loggingConfiguration
    )
    clerk.identityController.applyStorageClearToMemory(identityClear)
    initialFailedOperations.append(
      contentsOf: deleteInvalidatedAtomicIdentityIfNeeded(
        using: dependencies,
        identityClear: identityClear,
        loggingConfiguration: loggingConfiguration
      )
    )
    let preservedKeys = preservedKeysAfterStorageClear(
      usesAtomicLocalIdentity: usesAtomicLocalIdentity
    )
    clearPersistedKeychainItems(
      in: dependencies,
      preserving: preservedKeys,
      loggingConfiguration: loggingConfiguration
    )
    let clearOperation = deferredKeychainClearOperation(
      clerk: clerk,
      dependencies: dependencies,
      identityClear: identityClear,
      cacheManager: cacheManager,
      preservedKeys: preservedKeys,
      initialFailedOperations: initialFailedOperations,
      loggingConfiguration: loggingConfiguration
    )
    return PendingKeychainClear(
      clerk: clerk,
      dependencies: dependencies,
      clearOperation: clearOperation,
      identityClear: identityClear,
      cacheManager: cacheManager,
      loggingConfiguration: loggingConfiguration
    )
  }

  @MainActor
  private static func preserveWatchClearWatermarkIfNeeded(
    using dependencies: any Dependencies,
    usesAtomicLocalIdentity: Bool,
    loggingConfiguration: ClerkLogger.Configuration
  ) -> [String] {
    guard usesAtomicLocalIdentity else { return [] }
    do {
      _ = try WatchSyncMetadataStore(keychain: dependencies.watchSyncKeychain)
        .saveClearTombstone()
      return []
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to preserve the Watch clear watermark",
        configuration: loggingConfiguration
      )
      return ["preserve Watch clear watermark"]
    }
  }

  @MainActor
  private static func deleteInvalidatedAtomicIdentityIfNeeded(
    using dependencies: any Dependencies,
    identityClear: ClerkIdentityController.StorageClearContext,
    loggingConfiguration: ClerkLogger.Configuration
  ) -> [String] {
    guard let atomicIdentityStore = dependencies.atomicIdentityStore else { return [] }
    do {
      try atomicIdentityStore.deleteInvalidatingOperations(
        through: identityClear.invalidatedThroughRevision
      )
      return []
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to synchronously delete Clerk's atomic identity",
        configuration: loggingConfiguration
      )
      return ["delete atomic identity"]
    }
  }

  private static func preservedKeysAfterStorageClear(
    usesAtomicLocalIdentity: Bool
  ) -> Set<ClerkKeychainKey> {
    usesAtomicLocalIdentity
      ? [.sharedSessionSyncAdopted, .watchSyncMetadata]
      : [.sharedSessionSyncAdopted]
  }

  @MainActor
  private static func clearPersistedKeychainItems(
    in dependencies: any Dependencies,
    preserving preservedKeys: Set<ClerkKeychainKey>,
    loggingConfiguration: ClerkLogger.Configuration
  ) {
    clearAllKeychainItems(
      in: dependencies.appLocalKeychain,
      preserving: preservedKeys,
      configuration: loggingConfiguration
    )
    clearAllKeychainItems(
      in: dependencies.identityKeychain,
      preserving: preservedKeys,
      configuration: loggingConfiguration
    )
    clearKeychainItems(
      legacySharedCredentialKeys,
      in: dependencies.keychain,
      configuration: loggingConfiguration
    )
  }

  @MainActor
  private static func deferredKeychainClearOperation(
    clerk: Clerk,
    dependencies: any Dependencies,
    identityClear: ClerkIdentityController.StorageClearContext,
    cacheManager: CacheManager?,
    preservedKeys: Set<ClerkKeychainKey>,
    initialFailedOperations: [String],
    loggingConfiguration: ClerkLogger.Configuration
  ) -> Task<KeychainClearResult, Error> {
    clerk.identityController.enqueueLocalOperation { operationRevision in
      var failedOperations = initialFailedOperations
      let ownerSlotWithdrawal = await withdrawSharedSessionOwnerSlot(
        clerk: clerk,
        identityClear: identityClear,
        loggingConfiguration: loggingConfiguration
      )
      if let failedOperation = ownerSlotWithdrawal.failedOperation {
        failedOperations.append(failedOperation)
      }

      await cacheManager?.drainFrozenPersistence()
      failedOperations.append(
        contentsOf: strictlyClearPersistedKeychainItems(
          in: dependencies,
          preserving: preservedKeys,
          loggingConfiguration: loggingConfiguration
        )
      )
      let atomicIdentityFailures = await deleteAtomicIdentityIfNeeded(
        dependencies: dependencies,
        operationRevision: operationRevision,
        loggingConfiguration: loggingConfiguration
      )
      failedOperations.append(contentsOf: atomicIdentityFailures)

      guard failedOperations.isEmpty else {
        throw KeychainClearError(
          failedOperations: failedOperations,
          sharedTransportWithdrawn: ownerSlotWithdrawal.withdrawn
        )
      }
      return KeychainClearResult(
        sharedTransportWithdrawn: ownerSlotWithdrawal.withdrawn
      )
    }
  }

  @MainActor
  private static func withdrawSharedSessionOwnerSlot(
    clerk: Clerk,
    identityClear: ClerkIdentityController.StorageClearContext,
    loggingConfiguration: ClerkLogger.Configuration
  ) async -> (withdrawn: Bool, failedOperation: String?) {
    do {
      let withdrawn = try await clerk.identityController
        .deleteCapturedOwnerSlotAfterStorageClear(identityClear)
      return (withdrawn, nil)
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to withdraw Clerk's shared-session owner slot",
        configuration: loggingConfiguration
      )
      return (false, "withdraw shared-session owner slot")
    }
  }

  @MainActor
  private static func strictlyClearPersistedKeychainItems(
    in dependencies: any Dependencies,
    preserving preservedKeys: Set<ClerkKeychainKey>,
    loggingConfiguration: ClerkLogger.Configuration
  ) -> [String] {
    var failedOperations: [String] = []
    do {
      try clearAllKeychainItemsStrictly(
        in: dependencies.appLocalKeychain,
        preserving: preservedKeys,
        configuration: loggingConfiguration
      )
    } catch {
      failedOperations.append("clear app-local Keychain")
    }
    do {
      try clearAllKeychainItemsStrictly(
        in: dependencies.identityKeychain,
        preserving: preservedKeys,
        configuration: loggingConfiguration
      )
    } catch {
      failedOperations.append("clear identity Keychain")
    }
    do {
      try clearKeychainItemsStrictly(
        legacySharedCredentialKeys,
        in: dependencies.keychain,
        configuration: loggingConfiguration
      )
    } catch {
      failedOperations.append("clear legacy shared credentials")
    }
    return failedOperations
  }

  @MainActor
  private static func deleteAtomicIdentityIfNeeded(
    dependencies: any Dependencies,
    operationRevision: UInt64,
    loggingConfiguration: ClerkLogger.Configuration
  ) async -> [String] {
    guard let localIdentityIO = dependencies.atomicIdentityIO else { return [] }
    do {
      _ = try await localIdentityIO.delete(operationRevision: operationRevision)
      return []
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to delete Clerk's atomic identity",
        configuration: loggingConfiguration
      )
      return ["delete atomic identity"]
    }
  }

  @MainActor
  private static func finishKeychainClear(_ pendingClear: PendingKeychainClear) async throws {
    let result: Result<Void, any Error>
    let sharedTransportWithdrawn: Bool
    do {
      let clearResult = try await pendingClear.clearOperation.value
      result = .success(())
      sharedTransportWithdrawn = clearResult.sharedTransportWithdrawn
    } catch let error as KeychainClearError {
      result = .failure(error)
      sharedTransportWithdrawn = error.sharedTransportWithdrawn
    } catch {
      result = .failure(error)
      sharedTransportWithdrawn = false
    }
    pendingClear.clerk.identityController.finishStorageClear(
      pendingClear.identityClear,
      sharedTransportWithdrawn: sharedTransportWithdrawn
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
  private static func clearKeychainItems(
    _ keys: [ClerkKeychainKey],
    in keychain: any KeychainStorage,
    configuration: ClerkLogger.Configuration? = nil
  ) {
    for key in keys {
      do {
        try keychain.deleteItem(forKey: key.rawValue)
      } catch {
        ClerkLogger.logError(
          error,
          message: "Failed to delete legacy shared Keychain item '\(key.rawValue)'.",
          configuration: configuration
        )
      }
    }
  }

  @MainActor
  private static func clearKeychainItemsStrictly(
    _ keys: [ClerkKeychainKey],
    in keychain: any KeychainStorage,
    configuration: ClerkLogger.Configuration? = nil
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
          configuration: configuration
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
      configuration: loggingConfiguration
    )
    try clearAllKeychainItemsStrictly(
      in: dependencies.identityKeychain,
      preserving: preservedKeys,
      configuration: loggingConfiguration
    )
    try clearKeychainItemsStrictly(
      legacySharedCredentialKeys,
      in: dependencies.keychain,
      configuration: loggingConfiguration
    )
    if let localIdentityIO = dependencies.atomicIdentityIO {
      try await localIdentityIO.delete()
    } else {
      try dependencies.atomicIdentityStore?.delete()
    }
  }
}
