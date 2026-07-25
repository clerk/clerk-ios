//
//  Clerk+Reconfiguration.swift
//

import Foundation

extension Clerk {
  typealias ReconfigurationDependencyFactory = @MainActor (
    String,
    Clerk.Options,
    ClerkRuntimeScope
  ) throws -> any Dependencies

  typealias ReconfigurationSourceRetirement = @MainActor @Sendable (
    any Dependencies
  ) async throws -> Void

  private struct ReconfigurationRollbackState {
    let configurationEpoch: ClerkConfigurationEpoch
    let dependencies: any Dependencies
    let identity: ClerkIdentityController.RollbackState
  }

  private struct PreparedReconfiguration {
    let ownership: PersistenceTransitionOwnership
    let nextEpoch: ClerkConfigurationEpoch
    let dependencies: any Dependencies
    let plan: ReconfigurationPlan
    let rollbackState: ReconfigurationRollbackState
    let volatileIdentity: ClerkIdentitySnapshot?
    let sourceClearIntent: AppContainerIdentityClearIntent?
    let targetClearIntent: AppContainerIdentityClearIntent?
  }

  private struct CommittedReconfigurationFailure: Error {
    let underlyingError: any Error
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
    options: Clerk.Options,
    dependencyFactory: ReconfigurationDependencyFactory? = nil,
    sourceRetirement: ReconfigurationSourceRetirement? = nil
  ) async throws -> Clerk {
    let preparation = try await prepareReconfiguration(
      publishableKey: publishableKey,
      options: options,
      dependencyFactory: dependencyFactory
    )
    return try await installPreparedReconfiguration(
      preparation,
      sourceRetirement: sourceRetirement
    )
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
    options: Clerk.Options,
    dependencyFactory: ReconfigurationDependencyFactory?
  ) async throws -> PreparedReconfiguration {
    let nextEpoch = nextConfigurationEpoch
    let targetRuntimeScope = ClerkRuntimeScope(
      epoch: nextEpoch,
      runtimeState: runtimeState
    )
    let target: any Dependencies = if let dependencyFactory {
      try dependencyFactory(
        publishableKey,
        options,
        targetRuntimeScope
      )
    } else {
      try DependencyContainer(
        publishableKey: publishableKey,
        options: options,
        runtimeScope: targetRuntimeScope,
        deferSharedSessionAdoption: true
      )
    }
    try prepareReconfigurationTarget(target)
    let plan = reconfigurationPlan(with: target)
    if plan == .preserveIdentityAndMigrateSlot {
      try await settlePendingPublicationForTopologyChange()
    }
    try target.discardPendingPublicationWhenSharedSyncDisabled()
    let rollbackState = captureReconfigurationRollbackState()
    let volatileIdentity = try volatileIdentityForReconfiguration()
    let sourceClearIntent: AppContainerIdentityClearIntent?
    let targetClearIntent: AppContainerIdentityClearIntent?
    if plan == .replaceIdentity {
      sourceClearIntent = try makeAppContainerIdentityClearIntent()
      let targetConfiguration = target.configurationManager
      targetClearIntent = try Self.makeAppContainerIdentityClearIntent(
        dependencies: target,
        options: targetConfiguration.options,
        frontendApiUrl: targetConfiguration.frontendApiUrl,
        publishableKey: targetConfiguration.publishableKey
      )
    } else {
      sourceClearIntent = nil
      targetClearIntent = nil
    }
    try Task.checkCancellation()
    let ownership = try identityPersistenceOperationCoordinator
      .beginReconfiguration(epoch: configurationEpoch)
    suspendWatchConnectivityForPersistenceTransition()
    return PreparedReconfiguration(
      ownership: ownership,
      nextEpoch: nextEpoch,
      dependencies: target,
      plan: plan,
      rollbackState: rollbackState,
      volatileIdentity: volatileIdentity,
      sourceClearIntent: sourceClearIntent,
      targetClearIntent: targetClearIntent
    )
  }

  private func prepareReconfigurationTarget(
    _ target: any Dependencies
  ) throws {
    try SharedSessionOwnerSlotClearRecovery.recoverIfNeeded(
      in: target.sharedSessionOwnerSlotClearRecovery
    )
    try target.probeLocalIdentityPersistence()
  }

  private func volatileIdentityForReconfiguration() throws
    -> ClerkIdentitySnapshot?
  {
    guard dependencies.usesVolatileIdentityPersistence else {
      return nil
    }
    return try identityController.currentIdentitySnapshot()
  }

  private func installPreparedReconfiguration(
    _ preparation: PreparedReconfiguration,
    sourceRetirement: ReconfigurationSourceRetirement?
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
        topologyRollback: topologyRollback,
        sourceRetirement: sourceRetirement
      )
    } catch let failure as CommittedReconfigurationFailure {
      await blockAfterCommittedReconfigurationFailure(
        preparation.rollbackState
      )
      throw failure.underlyingError
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
      guard let sourceClearIntent = preparation.sourceClearIntent,
            let targetClearIntent = preparation.targetClearIntent
      else {
        throw AppContainerIdentityClearIntentError.invalidIntent
      }
      guard targetClearIntent.activeStorageMayOverlap(
        with: sourceClearIntent
      ) else {
        try await clearReconfigurationTarget(preparation)
        return nil
      }
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
    topologyRollback: SharedSessionTopologyMigration.Rollback?,
    sourceRetirement: ReconfigurationSourceRetirement?
  ) async throws {
    try identityPersistenceOperationCoordinator.validate(
      preparation.ownership,
      operation: .reconfigure,
      expectedEpoch: preparation.nextEpoch
    )

    if preparation.plan == .replaceIdentity {
      try await commitIdentityReplacement(preparation)
    } else if !preparation.plan.reusesOwnerSlot {
      let retireSource = sourceRetirement ?? { dependencies in
        try await SharedSessionOwnerSlotCleanup.deleteIfConfigured(
          in: dependencies
        )
      }
      try await Task { @MainActor in
        try await retireSource(preparation.rollbackState.dependencies)
      }.value
    }
    if topologyRollback?.publishedDestinationSlot != nil {
      Self.notifySharedSessionTopologyChange(
        in: preparation.dependencies
      )
    }
  }

  private func commitIdentityReplacement(
    _ preparation: PreparedReconfiguration
  ) async throws {
    guard let sourceClearIntent = preparation.sourceClearIntent,
          let targetClearIntent = preparation.targetClearIntent
    else {
      throw AppContainerIdentityClearIntentError.invalidIntent
    }
    let targetClearRequiresCommit = targetClearIntent
      .activeStorageMayOverlap(with: sourceClearIntent)

    // Keep both exact topologies in one durable transaction. A target clear can
    // overlap the source, and even a disjoint target can have legacy locations
    // that are not represented by its active dependency stores.
    let committedClearIntent =
      if !sourceClearIntent.hasSameRecoveryTopology(as: targetClearIntent) {
        try sourceClearIntent.includingClearIntent(targetClearIntent)
      } else {
        sourceClearIntent
      }
    switch appContainerIdentityClearIntentStore
      .recordResolvingWriteFailure(committedClearIntent)
    {
    case .recorded:
      break
    case .notRecorded(let error):
      throw error
    case .unresolved(let error):
      throw CommittedReconfigurationFailure(underlyingError: error)
    }

    do {
      try await Task { @MainActor in
        if targetClearRequiresCommit {
          try await self.clearReconfigurationTarget(preparation)
        }
        try await Self.clearLocalClerkStorageStrictly(
          in: preparation.rollbackState.dependencies,
          deleteSharedSessionOwnerSlot: false
        )
        try self.appContainerIdentityClearRecovery.recover(
          committedClearIntent
        )
        try self.appContainerIdentityClearIntentStore.remove(
          matching: committedClearIntent.transactionID
        )
      }.value
    } catch {
      throw CommittedReconfigurationFailure(underlyingError: error)
    }
  }

  private func clearReconfigurationTarget(
    _ preparation: PreparedReconfiguration
  ) async throws {
    try await Self.clearLocalClerkStorageStrictly(
      in: preparation.dependencies
    )
    try preparation.dependencies
      .markSharedSessionAdoptedWithoutMigratingCredentialsIfNeeded()
  }

  private func blockAfterCommittedReconfigurationFailure(
    _ rollbackState: ReconfigurationRollbackState
  ) async {
    setConfigurationEpoch(to: rollbackState.configurationEpoch)
    await resetRuntimeStateForReconfiguration()
    installConfiguration(
      dependencies: rollbackState.dependencies,
      bootstrapBlockReason: .pendingClear
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
