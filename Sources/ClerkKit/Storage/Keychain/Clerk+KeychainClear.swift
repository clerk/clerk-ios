//
//  Clerk+KeychainClear.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

extension Clerk {
  private enum KeychainClearOperation: Equatable {
    case persistOwnerSlotWithdrawalIntent
    case preventLegacyIdentityReadoption
    case preserveWatchClearWatermark
    case deleteAtomicIdentity
    case withdrawSharedSessionOwnerSlot
    case clearOwnerSlotWithdrawalIntent
    case clearAppLocalKeychain
    case clearIdentityKeychain
    case clearLegacySharedCredentials
    case keychainItem(String)

    var description: String {
      switch self {
      case .persistOwnerSlotWithdrawalIntent:
        "persist owner-slot withdrawal intent"
      case .preventLegacyIdentityReadoption:
        "prevent legacy identity re-adoption"
      case .preserveWatchClearWatermark:
        "preserve Watch clear watermark"
      case .deleteAtomicIdentity:
        "delete atomic identity"
      case .withdrawSharedSessionOwnerSlot:
        "withdraw shared-session owner slot"
      case .clearOwnerSlotWithdrawalIntent:
        "clear owner-slot withdrawal intent"
      case .clearAppLocalKeychain:
        "clear app-local Keychain"
      case .clearIdentityKeychain:
        "clear identity Keychain"
      case .clearLegacySharedCredentials:
        "clear legacy shared credentials"
      case .keychainItem(let key):
        key
      }
    }
  }

  private struct KeychainClearError: LocalizedError {
    let failedOperations: [KeychainClearOperation]
    let canReleaseSharedClearBarrier: Bool

    init(
      failedOperations: [KeychainClearOperation],
      canReleaseSharedClearBarrier: Bool = false
    ) {
      self.failedOperations = failedOperations
      self.canReleaseSharedClearBarrier = canReleaseSharedClearBarrier
    }

    var errorDescription: String? {
      let descriptions = failedOperations.map(\.description)
      return "Unable to complete Clerk Keychain clear: \(descriptions.joined(separator: ", "))."
    }
  }

  private struct KeychainClearResult {
    let canReleaseSharedClearBarrier: Bool
  }

  private struct OwnerSlotWithdrawalResult {
    let failedOperations: [KeychainClearOperation]
    let sharedTransportWithdrawn: Bool
  }

  private struct PendingKeychainClear {
    let clerk: Clerk
    let dependencies: any Dependencies
    let ownership: PersistenceTransitionOwnership
    let appContainerIntent: AppContainerIdentityClearIntent
    let clearOperation: Task<KeychainClearResult, Error>
    let identityClear: ClerkIdentityController.StorageClearContext
    let cacheManager: CacheManager?
    let loggingConfiguration: ClerkLogger.Configuration
  }

  private static func attemptKeychainClear(
    _ operation: KeychainClearOperation,
    recording failures: inout [KeychainClearOperation],
    logMessage: String? = nil,
    configuration: ClerkLogger.Configuration,
    perform: () throws -> Void
  ) {
    do {
      try perform()
    } catch {
      if let logMessage {
        ClerkLogger.logError(
          error,
          message: logMessage,
          configuration: configuration
        )
      }
      failures.append(operation)
    }
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

  @MainActor
  static func startKeychainClearIfNeeded(for clerk: Clerk) -> Task<Void, Error> {
    if let keychainClearTask = clerk.keychainClearTask {
      return keychainClearTask
    }
    if runtimeReconfigurationIsInProgress {
      return Task { @MainActor in
        await waitForRuntimeReconfigurationIfNeeded()
        try await startKeychainClearIfNeeded(for: clerk).value
      }
    }

    do {
      if let intent = try clerk.appContainerIdentityClearIntentStore.load() {
        return startPendingAppContainerIdentityClear(
          for: clerk,
          intent: intent
        )
      }
    } catch {
      clerk.identityPersistenceOperationCoordinator.cancelActiveTransition()
      let ownership = try? clerk.identityPersistenceOperationCoordinator
        .beginClear(epoch: clerk.configurationEpoch)
      clerk.identityPersistenceOperationCoordinator.block(
        ownership,
        reason: PersistenceFailureKind.classify(error).blockReason
      )
      return failedKeychainClearTask(
        for: clerk,
        error: error,
        message: "Failed to read Clerk's pending identity clear"
      )
    }

    let appContainerIntent: AppContainerIdentityClearIntent
    do {
      appContainerIntent = try clerk.makeAppContainerIdentityClearIntent()
    } catch {
      return failedKeychainClearTask(
        for: clerk,
        error: error,
        message: "Failed to prepare Clerk's durable identity-clear intent"
      )
    }

    do {
      try clerk.appContainerIdentityClearIntentStore.record(
        appContainerIntent
      )
    } catch let recordError {
      let pendingIntent: AppContainerIdentityClearIntent?
      do {
        pendingIntent = try clerk.appContainerIdentityClearIntentStore.load()
      } catch {
        blockUnresolvedIdentityClear(for: clerk)
        return failedKeychainClearTask(
          for: clerk,
          error: error,
          message: "Failed to resolve Clerk's durable identity-clear intent after a write error"
        )
      }
      guard let pendingIntent else {
        return failedKeychainClearTask(
          for: clerk,
          error: recordError,
          message: "Failed to record Clerk's durable identity-clear intent"
        )
      }
      guard pendingIntent == appContainerIntent else {
        blockUnresolvedIdentityClear(for: clerk)
        return failedKeychainClearTask(
          for: clerk,
          error: AppContainerIdentityClearIntentError
            .pendingIntentConflict,
          message: "Clerk found a conflicting durable identity-clear intent after a write error"
        )
      }
    }

    let clearOwnership: PersistenceTransitionOwnership
    do {
      clearOwnership =
        try clerk.identityPersistenceOperationCoordinator.beginClear(
          epoch: clerk.configurationEpoch
        )
      clerk.suspendWatchConnectivityForPersistenceTransition()
    } catch {
      return failedKeychainClearTask(
        for: clerk,
        error: error,
        message: "Failed to begin Clerk's durable identity clear"
      )
    }

    if clerk.dependencies.usesVolatileIdentityPersistence {
      return startVolatileKeychainClear(
        for: clerk,
        ownership: clearOwnership,
        appContainerIntent: appContainerIntent
      )
    }

    let pendingClear: PendingKeychainClear
    do {
      pendingClear = try beginKeychainClear(
        for: clerk,
        ownership: clearOwnership,
        appContainerIntent: appContainerIntent
      )
    } catch {
      clerk.identityPersistenceOperationCoordinator.block(
        clearOwnership,
        reason: .pendingClear
      )
      let loggingConfiguration = ClerkLogger.Configuration(options: clerk.options)
      let task = Task<Void, Error> { @MainActor in
        ClerkLogger.logError(
          error,
          message: "Failed to clear all Clerk Keychain items",
          configuration: loggingConfiguration
        )
        clerk.keychainClearTask = nil
        throw error
      }
      clerk.keychainClearTask = task
      return task
    }
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
      clerk.keychainClearTask = nil
      return try result.get()
    }
    clerk.keychainClearTask = task
    return task
  }

  @MainActor
  private static func failedKeychainClearTask(
    for clerk: Clerk,
    error: any Error,
    message: String
  ) -> Task<Void, Error> {
    let loggingConfiguration = ClerkLogger.Configuration(options: clerk.options)
    let task = Task<Void, Error> { @MainActor in
      ClerkLogger.logError(
        error,
        message: message,
        configuration: loggingConfiguration
      )
      clerk.keychainClearTask = nil
      throw error
    }
    clerk.keychainClearTask = task
    return task
  }

  @MainActor
  private static func blockUnresolvedIdentityClear(for clerk: Clerk) {
    clerk.identityPersistenceOperationCoordinator.block(
      nil,
      reason: .pendingClear
    )
    clerk.suspendWatchConnectivityForPersistenceTransition()
  }

  @MainActor
  private static func startPendingAppContainerIdentityClear(
    for clerk: Clerk,
    intent: AppContainerIdentityClearIntent
  ) -> Task<Void, Error> {
    let ownership: PersistenceTransitionOwnership
    do {
      ownership = try clerk.identityPersistenceOperationCoordinator.beginClear(
        epoch: clerk.configurationEpoch
      )
      clerk.suspendWatchConnectivityForPersistenceTransition()
      try clerk.identityPersistenceOperationCoordinator.validate(
        ownership,
        operation: .clear
      )
    } catch {
      return failedKeychainClearTask(
        for: clerk,
        error: error,
        message: "Failed to resume Clerk's pending identity clear"
      )
    }

    let cacheManager = clerk.cacheManager
    cacheManager?.freezePersistence()
    let identityClear = clerk.identityController.beginStorageClear()
    clerk.identityController.applyStorageClearToMemory(identityClear)
    clerk.identityController.resetRuntimeIdentity()
    do {
      try clerk.identityPersistenceOperationCoordinator.validate(
        ownership,
        operation: .clear
      )
    } catch {
      clerk.identityPersistenceOperationCoordinator.block(
        ownership,
        reason: .pendingClear
      )
      return failedKeychainClearTask(
        for: clerk,
        error: error,
        message: "Failed to resume Clerk's pending identity clear"
      )
    }

    let loggingConfiguration = ClerkLogger.Configuration(options: clerk.options)
    let task = Task<Void, Error> { @MainActor in
      let recoveryResult = Result {
        try clerk.recoverAppContainerIdentityClear(
          intent,
          protecting: clerk.dependencies
        )
      }
      await SessionTokenFetcher.shared.reset()
      await SessionTokensCache.shared.clear()

      do {
        try recoveryResult.get()
        if !clerk.dependencies.usesVolatileIdentityPersistence,
           clerk.dependencies.atomicIdentityStore == nil
        {
          if clerk
            .appContainerIdentityClearCanChangeCurrentPersistenceRouting(
              intent,
              protecting: clerk.dependencies
            )
          {
            throw AppContainerIdentityClearIntentError
              .runtimePersistenceRoutingRequiresRestart
          }
        }
        try clerk.appContainerIdentityClearIntentStore.remove(
          matching: intent.transactionID
        )
        clerk.identityController.finishStorageClear(
          identityClear,
          canReleaseSharedClearBarrier: true
        )
        cacheManager?.resumePersistence()
        clerk.identityPersistenceOperationCoordinator.finish(ownership)
        clerk.resumeWatchConnectivityAfterPersistenceTransition()
        clerk.keychainClearTask = nil
      } catch {
        clerk.identityController.finishStorageClear(
          identityClear,
          canReleaseSharedClearBarrier: false
        )
        clerk.identityPersistenceOperationCoordinator.block(
          ownership,
          reason: .pendingClear
        )
        ClerkLogger.logError(
          error,
          message: "Failed to complete Clerk's pending durable identity clear",
          configuration: loggingConfiguration
        )
        clerk.keychainClearTask = nil
        throw error
      }
    }
    clerk.keychainClearTask = task
    return task
  }

  @MainActor
  private static func startVolatileKeychainClear(
    for clerk: Clerk,
    ownership: PersistenceTransitionOwnership,
    appContainerIntent: AppContainerIdentityClearIntent
  ) -> Task<Void, Error> {
    let loggingConfiguration = ClerkLogger.Configuration(options: clerk.options)

    let pendingClear: PendingKeychainClear
    do {
      pendingClear = try beginKeychainClear(
        for: clerk,
        ownership: ownership,
        appContainerIntent: appContainerIntent
      )
    } catch {
      clerk.identityPersistenceOperationCoordinator.block(
        ownership,
        reason: .pendingClear
      )
      let task = Task<Void, Error> { @MainActor in
        ClerkLogger.logError(
          error,
          message: "Failed to clear the volatile Clerk identity",
          configuration: loggingConfiguration
        )
        clerk.keychainClearTask = nil
        throw error
      }
      clerk.keychainClearTask = task
      return task
    }

    let task = Task<Void, Error> { @MainActor in
      do {
        try await finishKeychainClear(
          pendingClear,
          completesTransition: false
        )
        try clerk.appContainerIdentityClearRecovery.recover(
          appContainerIntent
        )
        try clerk.appContainerIdentityClearIntentStore.remove(
          matching: appContainerIntent.transactionID
        )
        clerk.identityPersistenceOperationCoordinator.finish(ownership)
        clerk.resumeWatchConnectivityAfterPersistenceTransition()
        clerk.keychainClearTask = nil
      } catch {
        clerk.identityPersistenceOperationCoordinator.block(
          ownership,
          reason: .pendingClear
        )
        ClerkLogger.logError(
          error,
          message: "Failed to clear Clerk identity from durable storage",
          configuration: loggingConfiguration
        )
        clerk.keychainClearTask = nil
        throw error
      }
    }
    clerk.keychainClearTask = task
    return task
  }

  @MainActor
  private static func beginKeychainClear(
    for clerk: Clerk,
    ownership: PersistenceTransitionOwnership,
    appContainerIntent: AppContainerIdentityClearIntent
  ) throws -> PendingKeychainClear {
    let dependencies = clerk.dependencies
    let loggingConfiguration = ClerkLogger.Configuration(options: clerk.options)
    try clerk.identityPersistenceOperationCoordinator.validate(
      ownership,
      operation: .clear
    )
    if
      clerk.sharedSessionSyncCoordinator != nil
      || clerk.options.sharedSessionSync != nil,

      !dependencies.usesVolatileIdentityPersistence
    {
      do {
        guard let context = dependencies.sharedSessionOwnerSlotClearRecovery else {
          throw SharedSessionOwnerSlotClearRecoveryError.missingCurrentTopology
        }
        try SharedSessionOwnerSlotClearRecovery.markPending(in: context)
        try dependencies
          .markSharedSessionAdoptedWithoutMigratingCredentialsIfNeeded()
      } catch {
        throw KeychainClearError(
          failedOperations: [
            .persistOwnerSlotWithdrawalIntent,
            .preventLegacyIdentityReadoption,
          ]
        )
      }
    }
    let cacheManager = clerk.cacheManager
    cacheManager?.freezePersistence()
    let identityClear = clerk.identityController.beginStorageClear()
    let usesAtomicLocalIdentity = identityClear.usesAtomicLocalPersistence
    var initialFailedOperations: [KeychainClearOperation] = []
    if usesAtomicLocalIdentity {
      attemptKeychainClear(
        .preserveWatchClearWatermark,
        recording: &initialFailedOperations,
        logMessage: "Failed to preserve the Watch clear watermark",
        configuration: loggingConfiguration
      ) {
        _ = try WatchSyncMetadataStore(keychain: dependencies.watchSyncKeychain)
          .saveClearTombstone()
      }
    }
    clerk.identityController.applyStorageClearToMemory(identityClear)
    try clerk.identityPersistenceOperationCoordinator.validate(
      ownership,
      operation: .clear
    )
    if let atomicIdentityStore = dependencies.atomicIdentityStore {
      attemptKeychainClear(
        .deleteAtomicIdentity,
        recording: &initialFailedOperations,
        logMessage: "Failed to synchronously delete Clerk's atomic identity",
        configuration: loggingConfiguration
      ) {
        try atomicIdentityStore.deleteInvalidatingOperations(
          through: identityClear.invalidatedThroughRevision
        )
      }
    }
    var preservedKeys: Set<ClerkKeychainKey> = [.sharedSessionSyncAdopted]
    if usesAtomicLocalIdentity {
      preservedKeys.insert(.watchSyncMetadata)
    }
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
    let clearOperation = deferredKeychainClearOperation(
      clerk: clerk,
      dependencies: dependencies,
      ownership: ownership,
      identityClear: identityClear,
      cacheManager: cacheManager,
      preservedKeys: preservedKeys,
      initialFailedOperations: initialFailedOperations,
      loggingConfiguration: loggingConfiguration
    )
    return PendingKeychainClear(
      clerk: clerk,
      dependencies: dependencies,
      ownership: ownership,
      appContainerIntent: appContainerIntent,
      clearOperation: clearOperation,
      identityClear: identityClear,
      cacheManager: cacheManager,
      loggingConfiguration: loggingConfiguration
    )
  }

  @MainActor
  private static func deferredKeychainClearOperation(
    clerk: Clerk,
    dependencies: any Dependencies,
    ownership: PersistenceTransitionOwnership,
    identityClear: ClerkIdentityController.StorageClearContext,
    cacheManager: CacheManager?,
    preservedKeys: Set<ClerkKeychainKey>,
    initialFailedOperations: [KeychainClearOperation],
    loggingConfiguration: ClerkLogger.Configuration
  ) -> Task<KeychainClearResult, Error> {
    clerk.identityController.enqueueLocalOperation { operationRevision in
      try clerk.identityPersistenceOperationCoordinator.validate(
        ownership,
        operation: .clear
      )
      let withdrawalResult = await withdrawOwnerSlotIfNeeded(
        clerk: clerk,
        identityClear: identityClear,
        initialFailedOperations: initialFailedOperations,
        loggingConfiguration: loggingConfiguration
      )
      var failedOperations = withdrawalResult.failedOperations
      var atomicIdentityDeleted = !identityClear.usesAtomicLocalPersistence
        || !failedOperations.contains(.deleteAtomicIdentity)

      await cacheManager?.drainFrozenPersistence()
      clearPersistedIdentityItems(
        in: dependencies,
        preserving: preservedKeys,
        recording: &failedOperations,
        configuration: loggingConfiguration
      )

      if let localIdentityIO = dependencies.atomicIdentityIO {
        do {
          let didDelete = try await localIdentityIO.delete(
            operationRevision: operationRevision
          )
          if didDelete {
            atomicIdentityDeleted = true
            failedOperations.removeAll {
              $0 == .deleteAtomicIdentity
            }
          }
        } catch {
          ClerkLogger.logError(
            error,
            message: "Failed to delete Clerk's atomic identity",
            configuration: loggingConfiguration
          )
          if !failedOperations.contains(.deleteAtomicIdentity) {
            failedOperations.append(.deleteAtomicIdentity)
          }
        }
      }

      let canReleaseSharedClearBarrier: Bool
      do {
        try clerk.identityPersistenceOperationCoordinator.validate(
          ownership,
          operation: .clear
        )
        canReleaseSharedClearBarrier = try clearOwnerSlotWithdrawalIntentIfSafe(
          in: dependencies,
          identityClear: identityClear,
          sharedTransportWithdrawn: withdrawalResult.sharedTransportWithdrawn,
          atomicIdentityDeleted: atomicIdentityDeleted
        )
      } catch {
        ClerkLogger.logError(
          error,
          message: "Failed to clear Clerk's shared-session owner-slot withdrawal intent",
          configuration: loggingConfiguration
        )
        failedOperations.append(.clearOwnerSlotWithdrawalIntent)
        canReleaseSharedClearBarrier = false
      }

      guard failedOperations.isEmpty else {
        throw KeychainClearError(
          failedOperations: failedOperations,
          canReleaseSharedClearBarrier: canReleaseSharedClearBarrier
        )
      }
      return KeychainClearResult(
        canReleaseSharedClearBarrier: canReleaseSharedClearBarrier
      )
    }
  }

  @MainActor
  private static func clearPersistedIdentityItems(
    in dependencies: any Dependencies,
    preserving preservedKeys: Set<ClerkKeychainKey>,
    recording failedOperations: inout [KeychainClearOperation],
    configuration: ClerkLogger.Configuration
  ) {
    attemptKeychainClear(
      .clearAppLocalKeychain,
      recording: &failedOperations,
      configuration: configuration
    ) {
      try clearAllKeychainItemsStrictly(
        in: dependencies.appLocalKeychain,
        preserving: preservedKeys,
        configuration: configuration
      )
    }
    attemptKeychainClear(
      .clearIdentityKeychain,
      recording: &failedOperations,
      configuration: configuration
    ) {
      try clearAllKeychainItemsStrictly(
        in: dependencies.identityKeychain,
        preserving: preservedKeys,
        configuration: configuration
      )
    }
    attemptKeychainClear(
      .clearLegacySharedCredentials,
      recording: &failedOperations,
      configuration: configuration
    ) {
      try clearKeychainItemsStrictly(
        legacySharedCredentialKeys,
        in: dependencies.keychain,
        configuration: configuration
      )
    }
  }

  @MainActor
  private static func withdrawOwnerSlotIfNeeded(
    clerk: Clerk,
    identityClear: ClerkIdentityController.StorageClearContext,
    initialFailedOperations: [KeychainClearOperation],
    loggingConfiguration: ClerkLogger.Configuration
  ) async -> OwnerSlotWithdrawalResult {
    var failedOperations = initialFailedOperations
    guard identityClear.requiresOwnerSlotWithdrawal else {
      return OwnerSlotWithdrawalResult(
        failedOperations: failedOperations,
        sharedTransportWithdrawn: true
      )
    }

    let sharedTransportWithdrawn: Bool
    do {
      sharedTransportWithdrawn = try await clerk.identityController
        .deleteCapturedOwnerSlotAfterStorageClear(identityClear)
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to withdraw Clerk's shared-session owner slot",
        configuration: loggingConfiguration
      )
      failedOperations.append(.withdrawSharedSessionOwnerSlot)
      return OwnerSlotWithdrawalResult(
        failedOperations: failedOperations,
        sharedTransportWithdrawn: false
      )
    }

    return OwnerSlotWithdrawalResult(
      failedOperations: failedOperations,
      sharedTransportWithdrawn: sharedTransportWithdrawn
    )
  }

  @MainActor
  private static func clearOwnerSlotWithdrawalIntentIfSafe(
    in dependencies: any Dependencies,
    identityClear: ClerkIdentityController.StorageClearContext,
    sharedTransportWithdrawn: Bool,
    atomicIdentityDeleted: Bool
  ) throws -> Bool {
    guard identityClear.requiresOwnerSlotWithdrawal else { return true }
    guard sharedTransportWithdrawn, atomicIdentityDeleted else { return false }

    guard let context = dependencies.sharedSessionOwnerSlotClearRecovery,
          let intent = context.currentIntent
    else {
      throw SharedSessionOwnerSlotClearRecoveryError.missingCurrentTopology
    }
    try SharedSessionOwnerSlotClearRecovery.clearPendingIntent(
      matching: intent,
      in: context
    )
    return true
  }

  @MainActor
  private static func finishKeychainClear(
    _ pendingClear: PendingKeychainClear,
    completesTransition: Bool = true
  ) async throws {
    var result: Result<Void, any Error>
    var canReleaseSharedClearBarrier: Bool
    do {
      let clearResult = try await pendingClear.clearOperation.value
      result = .success(())
      canReleaseSharedClearBarrier = clearResult.canReleaseSharedClearBarrier
    } catch let error as KeychainClearError {
      result = .failure(error)
      canReleaseSharedClearBarrier = error.canReleaseSharedClearBarrier
    } catch {
      result = .failure(error)
      canReleaseSharedClearBarrier = false
    }
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    if case .success = result, completesTransition {
      do {
        if pendingClear.appContainerIntent.ownerSlot != nil,
           !pendingClear.identityClear.requiresOwnerSlotWithdrawal
        {
          try pendingClear.clerk.recoverAppContainerIdentityClear(
            pendingClear.appContainerIntent,
            protecting: nil
          )
        }
        try pendingClear.clerk.appContainerIdentityClearIntentStore.remove(
          matching: pendingClear.appContainerIntent.transactionID
        )
      } catch {
        result = .failure(error)
        canReleaseSharedClearBarrier = false
      }
    }

    let completedDurably = if case .success = result {
      true
    } else {
      false
    }
    pendingClear.clerk.identityController.finishStorageClear(
      pendingClear.identityClear,
      canReleaseSharedClearBarrier:
      completedDurably && canReleaseSharedClearBarrier
    )
    if pendingClear.clerk.dependencies === pendingClear.dependencies,
       pendingClear.clerk.cacheManager === pendingClear.cacheManager,
       completedDurably
    {
      pendingClear.cacheManager?.resumePersistence()
    }
    switch result {
    case .success:
      if completesTransition {
        pendingClear.clerk.identityPersistenceOperationCoordinator.finish(
          pendingClear.ownership
        )
        pendingClear.clerk
          .resumeWatchConnectivityAfterPersistenceTransition()
      }
    case .failure:
      pendingClear.clerk.identityPersistenceOperationCoordinator.block(
        pendingClear.ownership,
        reason: .pendingClear
      )
    }
    try result.get()
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
    var failures: [KeychainClearOperation] = []
    for key in keys {
      do {
        try keychain.deleteItem(forKey: key.rawValue)
      } catch {
        failures.append(.keychainItem(key.rawValue))
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
