//
//  Clerk+SharedSessionLifecycle.swift
//

import Foundation

extension Clerk {
  var sharedSessionLocalMutation: SharedSessionLocalMutation? {
    guard case .durable =
      identityPersistenceOperationCoordinator.identityCapability,
      case .unavailable =
      identityPersistenceOperationCoordinator
        .sharedSessionCapability,
        options.sharedSessionSync != nil
    else {
      return nil
    }
    return SharedSessionLocalMutation(
      baseGeneration: sharedSessionDegradationBaseGeneration
    )
  }

  @MainActor
  func startSharedSessionSyncIfNeeded(
    dependencies: any Dependencies,
    cacheManager: CacheManager,
    bootstrapOwnership: PersistenceTransitionOwnership
  ) -> Task<Bool, Never>? {
    guard !dependencies.usesVolatileIdentityPersistence,
          options.sharedSessionSync != nil
    else {
      return nil
    }
    guard options.keychainConfig.normalizedAccessGroup != nil,
          let ownerIdentifier = dependencies.sharedSessionOwnerIdentifier,
          !ownerIdentifier.isEmpty,
          let localIdentityStore = dependencies.atomicIdentityStore
    else {
      settleUnavailableSharedSession(
        error: ClerkClientError(
          message: "Shared session sync requires a Keychain access group, bundle identifier, and app-local identity store."
        ),
        coordinator: nil,
        cacheManager: cacheManager,
        ownership: bootstrapOwnership
      )
      return nil
    }

    do {
      let didAdoptSharedSession =
        try (dependencies as? DependencyContainer)?
          .performDeferredSharedSessionAdoptionIfNeeded() ?? false
      if didAdoptSharedSession {
        cacheManager.loadProvisionalLegacyClientForPresentation()
      }
      let localMutationPreparation =
        try SharedSessionRecoveryReconciler
          .preparePendingLocalMutationForActivation(
            in: dependencies
          )
      if localMutationPreparation?.publishedDestinationSlot != nil {
        Self.notifySharedSessionTopologyChange(in: dependencies)
      }
      try identityPersistenceOperationCoordinator.validate(
        bootstrapOwnership,
        operation: .bootstrap
      )
      let coordinator = try makeSharedSessionSyncCoordinator(
        dependencies: dependencies,
        ownerIdentifier: ownerIdentifier,
        localIdentityStore: localIdentityStore
      )
      sharedSessionSyncCoordinator = coordinator
      internalStateChanges.addObserver(coordinator)
      let initialTask = coordinator.start()
      return Task { @MainActor [weak self, weak coordinator] in
        _ = await initialTask.value
        guard let self, let coordinator else { return false }
        do {
          try identityPersistenceOperationCoordinator.validate(
            bootstrapOwnership,
            operation: .bootstrap
          )
          try await coordinator.waitForInitialReconciliation()
          try identityPersistenceOperationCoordinator.validate(
            bootstrapOwnership,
            operation: .bootstrap
          )
          identityPersistenceOperationCoordinator.setSharedSessionCapability(
            .active
          )
          sharedSessionDegradationBaseGeneration = nil
          identityPersistenceOperationCoordinator.finish(bootstrapOwnership)
          installWatchConnectivityIfAvailable()
          return true
        } catch is CancellationError {
          return false
        } catch {
          settleUnavailableSharedSession(
            error: error,
            failure:
            coordinator.lastReconciliationFailureKind,
            coordinator: coordinator,
            cacheManager: cacheManager,
            ownership: bootstrapOwnership
          )
          return false
        }
      }
    } catch {
      settleUnavailableSharedSession(
        error: error,
        coordinator: nil,
        cacheManager: cacheManager,
        ownership: bootstrapOwnership
      )
      return nil
    }
  }

  private func makeSharedSessionSyncCoordinator(
    dependencies: any Dependencies,
    ownerIdentifier: String,
    localIdentityStore: any SharedSessionLocalIdentityStoring
  ) throws -> SharedSessionSyncCoordinator {
    let namespace = SharedSessionNamespace(
      frontendApiUrl: frontendApiUrl,
      publishableKey: publishableKey
    )
    let slotStore = try SharedSessionOwnerSlotStore(
      keychainConfig: options.keychainConfig,
      namespace: namespace,
      ownerIdentifier: ownerIdentifier
    )
    return SharedSessionSyncCoordinator(
      ownerIdentifier: ownerIdentifier,
      instanceFingerprint: namespace.fingerprint,
      slotStore: slotStore,
      localIdentityStore: localIdentityStore,
      localIdentityIO: dependencies.atomicIdentityIO,
      notifier: SharedSessionSyncDarwinNotifier(
        keychainConfig: options.keychainConfig,
        instanceFingerprint: namespace.fingerprint
      ),
      configurationEpoch: configurationEpoch,
      clerk: self
    )
  }

  private func settleUnavailableSharedSession(
    error: any Error,
    failure: PersistenceFailureKind? = nil,
    coordinator: SharedSessionSyncCoordinator?,
    cacheManager: CacheManager,
    ownership: PersistenceTransitionOwnership
  ) {
    guard identityPersistenceOperationCoordinator.isActive(
      ownership,
      operation: .bootstrap
    )
    else {
      return
    }
    ClerkLogger.logError(
      error,
      message: "Shared session sync is unavailable. Clerk will continue with durable app-local identity."
    )
    coordinator?.deactivate()
    if let observedGeneration = coordinator?.currentMaximumGeneration,
       observedGeneration > 0
    {
      sharedSessionDegradationBaseGeneration = max(
        sharedSessionDegradationBaseGeneration ?? 0,
        observedGeneration
      )
    }
    if sharedSessionSyncCoordinator === coordinator {
      sharedSessionSyncCoordinator = nil
    }
    if let coordinator {
      internalStateChanges.removeObserver(coordinator)
    }
    do {
      try dependencies.atomicIdentityStore?
        .convertPendingPublicationToUnpublishedLocalMutation(
          baseGeneration: sharedSessionDegradationBaseGeneration
        )
    } catch {
      ClerkLogger.logError(
        error,
        message: "Shared session sync failed while preserving the pending app-local identity."
      )
      identityController.resetRuntimeIdentity()
      identityPersistenceOperationCoordinator.block(
        ownership,
        reason: PersistenceFailureKind.classify(error).blockReason
      )
      return
    }
    identityController.resetRuntimeIdentity()
    cacheManager.loadCachedData()
    identityPersistenceOperationCoordinator.setSharedSessionCapability(
      .unavailable(
        failure ?? PersistenceFailureKind.classify(error)
      )
    )
    identityPersistenceOperationCoordinator.finish(ownership)
    installWatchConnectivityIfAvailable()
  }

  static func notifySharedSessionTopologyChange(
    in dependencies: any Dependencies
  ) {
    guard let topology = SharedSessionSlotTopology(dependencies: dependencies) else { return }
    SharedSessionSyncDarwinNotifier(
      keychainConfig: topology.keychainConfig,
      instanceFingerprint: topology.instanceFingerprint
    ).post()
  }
}
