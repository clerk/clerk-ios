//
//  Clerk+Reconfiguration.swift
//

import Foundation

extension Clerk {
  private struct ReconfigurationRollbackState {
    let configurationEpoch: ClerkConfigurationEpoch
    let dependencies: any Dependencies
    let identity: ClerkIdentityController.RollbackState
  }

  private struct PreparedReconfiguration {
    let ownership: PersistenceTransitionOwnership
    let nextEpoch: ClerkConfigurationEpoch
    let dependencies: DependencyContainer
    let plan: ReconfigurationPlan
    let rollbackState: ReconfigurationRollbackState
    let volatileIdentity: ClerkIdentitySnapshot?
  }

  private enum ReconfigurationPlan: Equatable {
    case preserveIdentityAndSlot
    case preserveIdentityAndMigrateSlot
    case replaceIdentity

    var reusesOwnerSlot: Bool {
      self == .preserveIdentityAndSlot
    }
  }

  func performReconfiguration(
    publishableKey: String,
    options: Clerk.Options
  ) async throws -> Clerk {
    let preparation = try await prepareReconfiguration(
      publishableKey: publishableKey,
      options: options
    )
    return try await installPreparedReconfiguration(preparation)
  }

  @MainActor
  private func resetRuntimeStateForReconfiguration() async {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    identityController.resetRuntimeIdentity()
    environment = nil
    sessionsByUserId = [:]
    WebAuthentication.cancelCurrentSession()

    #if canImport(AuthenticationServices) && !os(watchOS)
    PasskeyHelper.cancelCurrentAuthorization()
    #endif
  }

  private func prepareReconfiguration(
    publishableKey: String,
    options: Clerk.Options
  ) async throws -> PreparedReconfiguration {
    let previousReadiness = persistenceStatus.readiness
    identityPersistenceOperationCoordinator.cancelActiveTransition()
    let ownership = try identityPersistenceOperationCoordinator
      .beginReconfiguration(epoch: configurationEpoch)
    suspendWatchConnectivityForPersistenceTransition()
    let nextEpoch = nextConfigurationEpoch

    do {
      let target = try DependencyContainer(
        publishableKey: publishableKey,
        options: options,
        runtimeScope: .init(
          epoch: nextEpoch,
          runtimeState: runtimeState
        ),
        deferSharedSessionAdoption: true
      )
      try prepareReconfigurationTarget(target)
      let plan = reconfigurationPlan(with: target)
      if plan == .preserveIdentityAndMigrateSlot {
        try await settlePendingPublicationForTopologyChange()
      }
      try identityPersistenceOperationCoordinator.validate(
        ownership,
        operation: .reconfigure
      )
      return try PreparedReconfiguration(
        ownership: ownership,
        nextEpoch: nextEpoch,
        dependencies: target,
        plan: plan,
        rollbackState: captureReconfigurationRollbackState(),
        volatileIdentity: volatileIdentityForReconfiguration()
      )
    } catch {
      restoreAfterFailedReconfigurationPreparation(
        ownership: ownership,
        previousReadiness: previousReadiness
      )
      throw error
    }
  }

  private func prepareReconfigurationTarget(
    _ target: DependencyContainer
  ) throws {
    try SharedSessionOwnerSlotClearRecovery.recoverIfNeeded(
      in: target.sharedSessionOwnerSlotClearRecovery
    )
    try target.probeLocalIdentityPersistence()
    try target.discardPendingPublicationWhenSharedSyncDisabled()
  }

  private func volatileIdentityForReconfiguration() throws
    -> ClerkIdentitySnapshot?
  {
    guard dependencies.usesVolatileIdentityPersistence else {
      return nil
    }
    return try identityController.currentIdentitySnapshot()
  }

  private func restoreAfterFailedReconfigurationPreparation(
    ownership: PersistenceTransitionOwnership,
    previousReadiness: PersistenceStatus.Readiness
  ) {
    if case .blocked(let reason) = previousReadiness {
      identityPersistenceOperationCoordinator.block(
        ownership,
        reason: reason
      )
    } else {
      identityPersistenceOperationCoordinator.finish(ownership)
    }
    resumeWatchConnectivityAfterPersistenceTransition()
  }

  private func installPreparedReconfiguration(
    _ preparation: PreparedReconfiguration
  ) async throws -> Clerk {
    setConfigurationEpoch(to: preparation.nextEpoch)
    await cleanupManagersAndDrainCache(
      deleteSharedSessionOwnerSlot: false,
      cancelPersistenceTransition: false
    )

    var topologyRollback: SharedSessionTopologyMigration.Rollback?
    do {
      try identityPersistenceOperationCoordinator.validate(
        preparation.ownership,
        operation: .reconfigure,
        expectedEpoch: preparation.nextEpoch
      )
      topologyRollback = try await prepareIdentityForReconfiguration(
        preparation
      )
      try await retireReconfigurationSource(
        preparation,
        topologyRollback: topologyRollback
      )
    } catch {
      restoreTopologyMigration(topologyRollback)
      restoreAfterFailedReconfiguration(preparation.rollbackState)
      throw error
    }

    await resetRuntimeStateForReconfiguration()
    installConfiguration(dependencies: preparation.dependencies)
    return self
  }

  private func prepareIdentityForReconfiguration(
    _ preparation: PreparedReconfiguration
  ) async throws -> SharedSessionTopologyMigration.Rollback? {
    switch preparation.plan {
    case .preserveIdentityAndSlot:
      guard let identity = preparation.volatileIdentity else { return nil }
      return try prepareLocalMutationForReconfiguration(
        identity,
        baseGeneration: sharedSessionDegradationBaseGeneration,
        dependencies: preparation.dependencies
      )
    case .preserveIdentityAndMigrateSlot:
      return try prepareMigratedIdentityForReconfiguration(preparation)
    case .replaceIdentity:
      try await Self.clearLocalClerkStorageStrictly(
        in: preparation.dependencies
      )
      try await Self.clearLocalClerkStorageStrictly(
        in: preparation.rollbackState.dependencies,
        deleteSharedSessionOwnerSlot: false
      )
      try preparation.dependencies
        .markSharedSessionAdoptedWithoutMigratingCredentialsIfNeeded()
      return nil
    }
  }

  private func prepareMigratedIdentityForReconfiguration(
    _ preparation: PreparedReconfiguration
  ) throws -> SharedSessionTopologyMigration.Rollback? {
    if let identity = preparation.volatileIdentity {
      return try prepareLocalMutationForReconfiguration(
        identity,
        baseGeneration: sharedSessionDegradationBaseGeneration,
        dependencies: preparation.dependencies
      )
    }
    if let sourceRecord = try preparation.rollbackState
      .dependencies.atomicIdentityStore?.loadRecord(),
      sourceRecord.hasUnpublishedLocalMutation,
      let identity = sourceRecord.acceptedIdentity
    {
      return try prepareLocalMutationForReconfiguration(
        identity,
        baseGeneration: sourceRecord.sharedSessionBaseGeneration,
        dependencies: preparation.dependencies
      )
    }
    return try Self.prepareAcceptedIdentityForTopologyChange(
      from: preparation.rollbackState.dependencies,
      to: preparation.dependencies
    )
  }

  private func prepareLocalMutationForReconfiguration(
    _ identity: ClerkIdentitySnapshot,
    baseGeneration: UInt64?,
    dependencies: any Dependencies
  ) throws -> SharedSessionTopologyMigration.Rollback? {
    try SharedSessionRecoveryReconciler
      .prepareLocalMutationForActivation(
        identity: identity,
        baseGeneration: baseGeneration,
        in: dependencies
      )
  }

  private func retireReconfigurationSource(
    _ preparation: PreparedReconfiguration,
    topologyRollback: SharedSessionTopologyMigration.Rollback?
  ) async throws {
    if !preparation.plan.reusesOwnerSlot {
      try await SharedSessionOwnerSlotCleanup.deleteIfConfigured(
        in: preparation.rollbackState.dependencies
      )
    }
    if topologyRollback?.publishedDestinationSlot != nil {
      Self.notifySharedSessionTopologyChange(
        in: preparation.dependencies
      )
    }
    try identityPersistenceOperationCoordinator.validate(
      preparation.ownership,
      operation: .reconfigure,
      expectedEpoch: preparation.nextEpoch
    )
  }

  private func restoreTopologyMigration(
    _ rollback: SharedSessionTopologyMigration.Rollback?
  ) {
    guard let rollback else { return }
    do {
      try rollback.restore()
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to roll back shared-session topology migration"
      )
    }
  }

  private func captureReconfigurationRollbackState() -> ReconfigurationRollbackState {
    ReconfigurationRollbackState(
      configurationEpoch: configurationEpoch,
      dependencies: dependencies,
      identity: identityController.captureRollbackState()
    )
  }

  private func restoreAfterFailedReconfiguration(
    _ state: ReconfigurationRollbackState
  ) {
    setConfigurationEpoch(to: state.configurationEpoch)
    identityController.restoreRollbackState(state.identity)
    installConfiguration(dependencies: state.dependencies)
  }

  private func settlePendingPublicationForTopologyChange() async throws {
    try await sharedSessionSyncCoordinator?
      .settlePendingPublicationForTopologyChange()

    guard try dependencies.atomicIdentityStore?
      .loadPendingPublication() == nil
    else {
      throw SharedSessionSyncCoordinatorError.pendingPublicationDidNotSettle
    }
  }

  private static func prepareAcceptedIdentityForTopologyChange(
    from source: any Dependencies,
    to destination: any Dependencies
  ) throws -> SharedSessionTopologyMigration.Rollback? {
    let sourceRecord = try source.atomicIdentityStore?.loadRecord()
    guard sourceRecord?.pendingPublication == nil else {
      throw SharedSessionSyncCoordinatorError.pendingPublicationDidNotSettle
    }
    guard let identity = sourceRecord?.acceptedIdentity,
          let destinationIdentityStore = destination.atomicIdentityStore
    else {
      return nil
    }

    let sourceTopology = SharedSessionSlotTopology(dependencies: source)
    let destinationTopology = SharedSessionSlotTopology(dependencies: destination)
    let sourceOwnerToExclude: String? = if let sourceTopology,
                                           let destinationTopology,
                                           sourceTopology.hasSameStore(as: destinationTopology)
    {
      sourceTopology.ownerIdentifier
    } else {
      nil
    }

    return try SharedSessionTopologyMigration.prepare(
      identity: identity,
      destinationIdentityStore: destinationIdentityStore,
      destinationSlotStore: destinationTopology?.makeOwnerSlotStore(),
      destinationInstanceFingerprint: destinationTopology?.instanceFingerprint,
      destinationOwnerIdentifier: destinationTopology?.ownerIdentifier,
      excludingSourceOwnerIdentifier: sourceOwnerToExclude
    )
  }

  private func reconfigurationPlan(
    with newDependencies: any Dependencies
  ) -> ReconfigurationPlan {
    let preservesIdentity = publishableKey
      == newDependencies.configurationManager.publishableKey
      && (options.sharedSessionSync != nil
        || newDependencies.configurationManager.options.sharedSessionSync != nil)
    guard preservesIdentity else {
      return .replaceIdentity
    }
    return canReuseSharedSessionOwnerSlot(with: newDependencies)
      ? .preserveIdentityAndSlot
      : .preserveIdentityAndMigrateSlot
  }

  func canReuseSharedSessionOwnerSlot(
    with newDependencies: any Dependencies
  ) -> Bool {
    guard let currentTopology = SharedSessionSlotTopology(
      dependencies: dependencies
    ),
      let newTopology = SharedSessionSlotTopology(dependencies: newDependencies)
    else {
      return false
    }

    return currentTopology.hasSameOwnerSlot(as: newTopology)
  }
}
