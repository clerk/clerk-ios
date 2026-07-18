//
//  Clerk+Keychain.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

extension Clerk {
  private struct PendingKeychainClear {
    let clerk: Clerk
    let dependencies: any Dependencies
    let usesAtomicLocalIdentity: Bool
    let localIdentityDeletion: Task<Void, Error>?
    let coordinator: SharedSessionSyncCoordinator?
    let cacheManager: CacheManager?
  }

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
  /// This method uses a best-effort approach - errors are logged but don't prevent deletion
  /// of other items. Clerk must be configured before calling this method.
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
  @MainActor
  public static func clearAllKeychainItemsAndWait() async {
    await Clerk.shared.clearAllKeychainItemsAndWait()
  }

  @MainActor
  func clearAllKeychainItemsAndWait() async {
    await Self.startKeychainClearIfNeeded(for: self).value
  }

  @MainActor
  static func startKeychainClearIfNeeded(for clerk: Clerk) -> Task<Void, Never> {
    if let keychainClearTask = clerk.keychainClearTask {
      return keychainClearTask
    }

    let taskID = UUID()
    let pendingClear = beginKeychainClear(for: clerk)
    let operation: @MainActor @Sendable () async -> Void = { [weak clerk] in
      await finishKeychainClear(pendingClear)
      guard let clerk, clerk.keychainClearTaskID == taskID else { return }
      clerk.keychainClearTask = nil
      clerk.keychainClearTaskID = nil
    }
    let task = clerk.scheduleManagedTask(operation: operation)
      ?? Task { @MainActor in await operation() }
    clerk.keychainClearTaskID = taskID
    clerk.keychainClearTask = task
    return task
  }

  @MainActor
  private static func beginKeychainClear(for clerk: Clerk) -> PendingKeychainClear {
    let dependencies = clerk.dependencies
    let usesAtomicLocalIdentity = dependencies.sharedSessionLocalIdentityStore != nil
    let cacheManager = clerk.cacheManager
    cacheManager?.freezePersistence()
    clerk.localIdentityOperationRevision &+= 1
    clerk.localIdentityInvalidatedThroughRevision = clerk.localIdentityOperationRevision
    clerk.localIdentityDeviceToken = nil
    let coordinator = clerk.sharedSessionSyncCoordinator
    coordinator?.beginLocalClear()
    if usesAtomicLocalIdentity {
      do {
        _ = try WatchSyncMetadataStore(keychain: dependencies.watchSyncKeychain)
          .saveClearTombstone()
      } catch {
        ClerkLogger.logError(error, message: "Failed to preserve the Watch clear watermark")
      }
      clerk.fenceClientResponsesAfterDeviceTokenChange()
      clerk.isApplyingSharedSessionIdentity = true
      clerk.lastClientServerFetchDate = nil
      clerk.client = nil
      clerk.isApplyingSharedSessionIdentity = false
      clerk.emitInternalStateChange(.localStorageDidClear)
    }
    let preservedKeys: Set<ClerkKeychainKey> = usesAtomicLocalIdentity
      ? [.sharedSessionSyncAdopted, .watchSyncMetadata]
      : [.sharedSessionSyncAdopted]
    clearAllKeychainItems(in: dependencies.appLocalKeychain, preserving: preservedKeys)
    clearAllKeychainItems(in: dependencies.identityKeychain, preserving: preservedKeys)
    let localIdentityDeletion = dependencies.sharedSessionLocalIdentityIO.map { localIdentityIO in
      clerk.enqueueLocalIdentityOperation { operationRevision in
        await coordinator?.deleteOwnSlotAfterLocalClear()
        await cacheManager?.drainFrozenPersistence()
        clearAllKeychainItems(in: dependencies.appLocalKeychain, preserving: preservedKeys)
        clearAllKeychainItems(in: dependencies.identityKeychain, preserving: preservedKeys)
        _ = try await localIdentityIO.delete(operationRevision: operationRevision)
      }
    }
    if !usesAtomicLocalIdentity {
      clerk.fenceClientResponsesAfterDeviceTokenChange()
    }
    return PendingKeychainClear(
      clerk: clerk,
      dependencies: dependencies,
      usesAtomicLocalIdentity: usesAtomicLocalIdentity,
      localIdentityDeletion: localIdentityDeletion,
      coordinator: coordinator,
      cacheManager: cacheManager
    )
  }

  @MainActor
  private static func finishKeychainClear(_ pendingClear: PendingKeychainClear) async {
    do {
      try await pendingClear.localIdentityDeletion?.value
    } catch {
      ClerkLogger.logError(error, message: "Failed to delete Clerk's app-local shared-session identity")
    }
    if pendingClear.localIdentityDeletion == nil {
      await pendingClear.coordinator?.deleteOwnSlotAfterLocalClear()
      await pendingClear.cacheManager?.drainFrozenPersistence()
      let preservedKeys: Set<ClerkKeychainKey> = pendingClear.usesAtomicLocalIdentity
        ? [.sharedSessionSyncAdopted, .watchSyncMetadata]
        : [.sharedSessionSyncAdopted]
      clearAllKeychainItems(
        in: pendingClear.dependencies.appLocalKeychain,
        preserving: preservedKeys
      )
      clearAllKeychainItems(
        in: pendingClear.dependencies.identityKeychain,
        preserving: preservedKeys
      )
    }
    if pendingClear.clerk.dependencies === pendingClear.dependencies,
       pendingClear.clerk.cacheManager === pendingClear.cacheManager
    {
      pendingClear.cacheManager?.resumePersistence()
    }
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
  static func clearAllKeychainItemsStrictly(
    in keychain: any KeychainStorage,
    preserving preservedKeys: Set<ClerkKeychainKey> = [.sharedSessionSyncAdopted]
  ) throws {
    var failures: [String] = []

    for key in ClerkKeychainKey.allCases where !preservedKeys.contains(key) {
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
  static func clearLocalClerkStorageStrictly(
    in dependencies: any Dependencies,
    deleteSharedSessionOwnerSlot: Bool = true
  ) async throws {
    _ = try WatchSyncMetadataStore(keychain: dependencies.watchSyncKeychain)
      .saveClearTombstone()
    let preservedKeys: Set<ClerkKeychainKey> = [
      .sharedSessionSyncAdopted,
      .watchSyncMetadata,
    ]
    let configuration = dependencies.configurationManager
    if deleteSharedSessionOwnerSlot,
       configuration.options.sharedSessionSync != nil,
       let ownerIdentifier = dependencies.sharedSessionOwnerIdentifier
    {
      let namespace = SharedSessionNamespace(
        frontendApiUrl: configuration.frontendApiUrl,
        publishableKey: configuration.publishableKey
      )
      let slotStore = try SharedSessionOwnerSlotStore(
        keychainConfig: configuration.options.keychainConfig,
        namespace: namespace,
        ownerIdentifier: ownerIdentifier
      )
      try await SharedSessionSlotIO(store: slotStore).deleteOwnSlot()
    }

    try clearAllKeychainItemsStrictly(
      in: dependencies.appLocalKeychain,
      preserving: preservedKeys
    )
    try clearAllKeychainItemsStrictly(
      in: dependencies.identityKeychain,
      preserving: preservedKeys
    )
    if let localIdentityIO = dependencies.sharedSessionLocalIdentityIO {
      try await localIdentityIO.delete()
    } else {
      try dependencies.sharedSessionLocalIdentityStore?.delete()
    }
  }

  @MainActor
  static func deleteSharedSessionOwnerSlotIfAccessible(
    in dependencies: any Dependencies
  ) async {
    let configuration = dependencies.configurationManager
    guard configuration.options.sharedSessionSync != nil,
          let ownerIdentifier = dependencies.sharedSessionOwnerIdentifier
    else {
      return
    }

    do {
      let namespace = SharedSessionNamespace(
        frontendApiUrl: configuration.frontendApiUrl,
        publishableKey: configuration.publishableKey
      )
      let slotStore = try SharedSessionOwnerSlotStore(
        keychainConfig: configuration.options.keychainConfig,
        namespace: namespace,
        ownerIdentifier: ownerIdentifier
      )
      try await SharedSessionSlotIO(store: slotStore).deleteOwnSlot()
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to delete the previous shared-session owner slot after reconfiguration"
      )
    }
  }
}
