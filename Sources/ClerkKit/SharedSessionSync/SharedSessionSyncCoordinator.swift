//
//  SharedSessionSyncCoordinator.swift
//  Clerk
//

import Foundation

enum SharedSessionSyncCoordinatorError: Error, Equatable {
  case initialReconciliationFailed
  case reconciliationFailed
  case missingWinnerForPendingPublication
  case pendingPublicationOwnerMismatch
}

@MainActor
final class SharedSessionSyncCoordinator: ClerkInternalStateChangeObserver {
  private enum PublicationCheckpoint {
    case none
    case response(
      baseGeneration: UInt64,
      requestDeviceToken: String?
    )
  }

  private struct Publication {
    let state: SharedSessionIdentityEvent.State
    let deviceToken: String?
    let client: Client?
    let serverDate: Date?
    let baseGeneration: UInt64?
    let checkpoint: PublicationCheckpoint
  }

  private struct NetworkResponseLineage {
    let rootGeneration: UInt64
    let frontierGeneration: UInt64
    let deviceToken: String?
  }

  private struct ReconciliationResult {
    let didChange: Bool
    let succeeded: Bool
  }

  private let ownerIdentifier: String
  private let instanceFingerprint: String
  private let slotStore: any SharedSessionSlotStoring
  private let slotIO: SharedSessionSlotIO
  private let localIdentityStore: any SharedSessionLocalIdentityStoring
  private let localIdentityIO: SharedSessionLocalIdentityIO
  private let notifier: any SharedSessionSyncNotifying
  private let configurationEpoch: ClerkConfigurationEpoch
  private let logError: (any Error, String) -> Void
  private weak var clerk: Clerk?

  private(set) var acceptedEventID: UUID?
  private(set) var currentMaximumGeneration: UInt64 = 0
  private(set) var currentDeviceToken: String?
  private var reconciliationTask: Task<Bool, Never>?
  private var reconciliationTaskID: UUID?
  private var initialReconciliationTask: Task<Bool, Never>?
  private var initialReconciliationTaskID: UUID?
  private var initialReconciliationSucceeded: Bool?
  private var serializedOperationTail: Task<Void, Never>?
  private var reconcileAgain = false
  private var isInstalled = true
  private var operationRevision: UInt64 = 0
  private var responseOrderingGate = ClientResponseOrderingGate()
  private var networkResponseLineage: NetworkResponseLineage?
  private var isLocalClearInProgress = false
  private var requiresSuccessfulReconciliation = false

  init(
    ownerIdentifier: String,
    instanceFingerprint: String,
    slotStore: any SharedSessionSlotStoring,
    localIdentityStore: any SharedSessionLocalIdentityStoring,
    localIdentityIO: SharedSessionLocalIdentityIO? = nil,
    notifier: any SharedSessionSyncNotifying,
    configurationEpoch: ClerkConfigurationEpoch,
    clerk: Clerk,
    logError: @escaping (any Error, String) -> Void = {
      ClerkLogger.logError($0, message: $1)
    }
  ) {
    self.ownerIdentifier = ownerIdentifier
    self.instanceFingerprint = instanceFingerprint
    self.slotStore = slotStore
    slotIO = SharedSessionSlotIO(store: slotStore)
    self.localIdentityStore = localIdentityStore
    self.localIdentityIO = localIdentityIO ?? SharedSessionLocalIdentityIO(store: localIdentityStore)
    self.notifier = notifier
    self.configurationEpoch = configurationEpoch
    self.logError = logError
    self.clerk = clerk
    currentDeviceToken = (try? localIdentityStore.load()?.deviceToken) ?? clerk.deviceToken

    notifier.setHandler { [weak self] in
      self?.requestReconciliation()
    }
  }

  @discardableResult
  func hydrateInitialSharedState() -> Bool {
    guard initialReconciliationTask == nil,
          reconciliationTask == nil,
          serializedOperationTail == nil
    else {
      return false
    }

    do {
      return try reduceApplyAndReplicateSynchronously()
    } catch {
      requiresSuccessfulReconciliation = true
      logError(error, "Failed to hydrate initial shared-session owner slots")
      return false
    }
  }

  func start() -> Task<Bool, Never> {
    if let initialReconciliationTask {
      return initialReconciliationTask
    }
    let task = scheduleReconciliation()
    initialReconciliationTask = task
    initialReconciliationTaskID = reconciliationTaskID
    initialReconciliationSucceeded = nil
    return task
  }

  func waitForInitialReconciliation() async throws {
    _ = await start().value
    guard initialReconciliationSucceeded == true else {
      initialReconciliationTask = nil
      initialReconciliationTaskID = nil
      initialReconciliationSucceeded = nil
      throw SharedSessionSyncCoordinatorError.initialReconciliationFailed
    }
  }

  func waitForPendingOperations() async {
    _ = await serializedOperationTail?.value
  }

  func captureRequestIdentity(
    startupClientRefreshTakeoverID: UUID? = nil
  ) async throws -> ClerkIdentityRequestSnapshot {
    let task = enqueueSerializedOperation { [weak self] in
      guard let self,
            let clerk,
            isCurrent(clerk: clerk),
            !isLocalClearInProgress
      else {
        throw CancellationError()
      }
      try await ensureSuccessfulReconciliationIfNeeded()
      return try clerk.identityController.captureSerializedRequestIdentity(
        baseGeneration: currentMaximumGeneration,
        deviceToken: currentDeviceToken,
        startupClientRefreshTakeoverID: startupClientRefreshTakeoverID
      )
    }
    return try await task.value
  }

  func handle(_ change: ClerkInternalStateChange, from _: Clerk) throws {
    switch change {
    case .applicationDidEnterForeground:
      requestReconciliation()
    case .clientDidChange, .deviceTokenDidChange, .environmentDidChange,
         .identityDidChange, .localStorageDidClear:
      break
    }
  }

  @discardableResult
  func reloadFromSharedStorage() async -> Bool {
    await scheduleReconciliation().value
  }

  func handleNetworkResponse(_ context: ClientSyncResponseContext) async throws {
    let task = enqueueSerializedOperation { [weak self] in
      guard let self else { throw CancellationError() }
      let didApply = try await performPublication {
        guard let clerk, isCurrent(clerk: clerk) else {
          throw CancellationError()
        }
        if let clientResponseGeneration = context.clientResponseGeneration,
           clientResponseGeneration != clerk.clientResponseGeneration
        {
          return nil
        }
        guard let baseGeneration = context.baseGeneration,
              context.update != .invalid,
              responseCanPublish(
                from: baseGeneration,
                requestDeviceToken: context.requestDeviceToken
              ),
              let identity = try context.resolvedIdentityPayload(
                currentDeviceToken: currentDeviceToken,
                currentClient: clerk.authoritativeClient,
                currentServerDate: clerk.lastClientServerFetchDate
              ),
              responseCanBeAccepted(
                sequence: context.responseSequence,
                serverDate: context.serverDate,
                incomingClient: identity.client,
                currentClient: clerk.authoritativeClient
              )
        else {
          return nil
        }
        return Publication(
          state: identity.state,
          deviceToken: identity.deviceToken,
          client: identity.client,
          serverDate: identity.serverDate,
          baseGeneration: nil,
          checkpoint: .response(
            baseGeneration: baseGeneration,
            requestDeviceToken: context.requestDeviceToken
          )
        )
      }
      if didApply {
        responseOrderingGate.record(
          sequence: context.responseSequence,
          serverDate: context.serverDate
        )
      }
      return didApply
    }
    try await withTaskCancellationHandler {
      _ = try await task.value
    } onCancel: {
      task.cancel()
    }
  }

  @discardableResult
  func publishLocalIdentity(
    state: SharedSessionIdentityEvent.State,
    deviceToken: String?,
    client: Client?,
    serverDate: Date?,
    baseGeneration: UInt64? = nil
  ) async throws -> Bool {
    try await enqueuePublication(
      Publication(
        state: state,
        deviceToken: deviceToken,
        client: client,
        serverDate: serverDate,
        baseGeneration: baseGeneration,
        checkpoint: .none
      )
    )
  }

  func enqueueSerializedLocalIdentityOperation<T: Sendable>(
    _ operation: @escaping @MainActor @Sendable () async throws -> T
  ) -> Task<T, Error> {
    enqueueSerializedOperation(operation)
  }

  func publishReservedLocalIdentity(
    state: SharedSessionIdentityEvent.State,
    deviceToken: String?,
    client: Client?,
    serverDate: Date?,
    baseGeneration: UInt64? = nil
  ) async throws -> Bool {
    try await performPublication(
      Publication(
        state: state,
        deviceToken: deviceToken,
        client: client,
        serverDate: serverDate,
        baseGeneration: baseGeneration,
        checkpoint: .none
      )
    )
  }
}

extension SharedSessionSyncCoordinator {
  private func enqueuePublication(_ publication: Publication) async throws -> Bool {
    let task = enqueueSerializedOperation { [weak self] in
      guard let self else { throw CancellationError() }
      return try await performPublication(publication)
    }
    return try await withTaskCancellationHandler {
      try await task.value
    } onCancel: {
      task.cancel()
    }
  }

  private func performPublication(_ publication: Publication) async throws -> Bool {
    try await performPublication { publication }
  }

  private func performPublication(
    resolve: @MainActor () throws -> Publication?
  ) async throws -> Bool {
    guard let clerk, isCurrent(clerk: clerk), !isLocalClearInProgress else {
      throw CancellationError()
    }

    try await ensureSuccessfulReconciliationIfNeeded()
    _ = try await resumePendingPublicationIfNeeded()
    guard let publication = try resolve() else { return false }
    guard isCurrent(clerk: clerk),
          !isLocalClearInProgress,
          checkpointAllowsPublication(publication.checkpoint)
    else {
      return false
    }

    operationRevision &+= 1
    let publicationRevision = operationRevision
    let generation = try SharedSessionIdentityEvent.nextGeneration(
      after: publication.baseGeneration ?? currentMaximumGeneration
    )
    let event = try SharedSessionIdentityEvent(
      id: UUID(),
      originOwnerIdentifier: ownerIdentifier,
      generation: generation,
      state: publication.state,
      deviceToken: publication.deviceToken.nilIfEmpty,
      client: publication.client,
      serverDate: publication.serverDate
    ).validated()

    var didStage = false
    do {
      try await performCheckedOperation(
        revision: publicationRevision,
        clerk: clerk,
        operation: {
          try await self.localIdentityIO.stagePendingPublication(event)
        },
        didComplete: {
          didStage = true
          self.requiresSuccessfulReconciliation = true
        }
      )

      do {
        try await performCheckedOperation(
          revision: publicationRevision,
          clerk: clerk
        ) {
          try await self.saveOwn(event)
        }
      } catch let error as SharedSessionOwnerSlotStoreError {
        if case .futureSchemaVersion = error {
          try await performCheckedOperation(
            revision: publicationRevision,
            clerk: clerk,
            operation: {
              try await self.localIdentityIO.clearPendingPublication()
            },
            didComplete: {
              didStage = false
            }
          )
          _ = try await reduceApplyAndReplicate()
          return false
        }
        throw error
      }

      _ = try await performCheckedOperation(
        revision: publicationRevision,
        clerk: clerk
      ) {
        try await self.reduceApplyAndReplicate(
          clearingPendingPublicationID: event.id,
          networkResponseCandidate: self.networkResponseCandidate(
            for: publication.checkpoint,
            eventID: event.id
          )
        )
      }
      notifier.post()
      return acceptedEventID == event.id
    } catch {
      if didStage, canScheduleRecovery(clerk: clerk) {
        requestReconciliation()
      }
      throw error
    }
  }

  func deactivate() {
    isInstalled = false
    operationRevision &+= 1
    responseOrderingGate.reset()
    networkResponseLineage = nil
    notifier.setHandler {}
    reconciliationTask?.cancel()
  }

  func shutdown(deleteOwnSlot: Bool) async {
    deactivate()
    _ = await reconciliationTask?.value
    reconciliationTask = nil
    reconciliationTaskID = nil
    _ = await serializedOperationTail?.value
    serializedOperationTail = nil
    reconcileAgain = false

    guard deleteOwnSlot else { return }
    do {
      try await slotIO.deleteOwnSlot()
    } catch {
      logError(error, "Failed to delete this app's shared-session owner slot")
    }
    do {
      try await localIdentityIO.clearPendingPublication()
    } catch {
      logError(error, "Failed to discard the pending shared-session publication")
    }
  }

  func beginLocalClear() {
    guard !isLocalClearInProgress else { return }
    isLocalClearInProgress = true
    operationRevision &+= 1
    responseOrderingGate.reset()
    networkResponseLineage = nil
    acceptedEventID = nil
    currentDeviceToken = nil
    reconciliationTask?.cancel()
    reconcileAgain = false
  }

  func deleteOwnSlotDuringLocalClear() async throws {
    let task = enqueueSerializedOperation { [weak self] in
      guard let self else { return }
      var firstError: (any Error)?
      do {
        try await slotIO.deleteOwnSlot()
      } catch {
        firstError = error
      }
      do {
        try await localIdentityIO.clearPendingPublication()
      } catch {
        firstError = firstError ?? error
      }
      if let firstError {
        throw firstError
      }
    }
    try await task.value
  }

  func endLocalClear() {
    isLocalClearInProgress = false
  }
}

extension SharedSessionSyncCoordinator {
  private func requestReconciliation() {
    _ = scheduleReconciliation()
  }

  private func scheduleReconciliation() -> Task<Bool, Never> {
    if let reconciliationTask {
      reconcileAgain = true
      return reconciliationTask
    }

    let taskID = UUID()
    let operation = enqueueSerializedOperation { [weak self] in
      guard let self else {
        return ReconciliationResult(didChange: false, succeeded: false)
      }
      return await runReconciliationLoop()
    }
    let task = Task { @MainActor [weak self] in
      let result = await (try? operation.value)
        ?? ReconciliationResult(didChange: false, succeeded: false)
      self?.recordInitialReconciliationResult(result, taskID: taskID)
      self?.finishReconciliationTask(taskID)
      return result.didChange
    }
    reconciliationTaskID = taskID
    reconciliationTask = task
    return task
  }

  private func finishReconciliationTask(_ taskID: UUID) {
    guard reconciliationTaskID == taskID else { return }
    let shouldScheduleFollowup = reconcileAgain
      && isInstalled
      && !isLocalClearInProgress
    reconcileAgain = false
    reconciliationTask = nil
    reconciliationTaskID = nil
    if shouldScheduleFollowup {
      requestReconciliation()
    }
  }

  private func recordInitialReconciliationResult(
    _ result: ReconciliationResult,
    taskID: UUID
  ) {
    if result.succeeded {
      initialReconciliationSucceeded = true
    } else if initialReconciliationTaskID == taskID,
              initialReconciliationSucceeded != true
    {
      initialReconciliationSucceeded = false
    }
  }

  private func runReconciliationLoop() async -> ReconciliationResult {
    var didChange = false

    repeat {
      reconcileAgain = false
      guard let clerk, isCurrent(clerk: clerk), !isLocalClearInProgress else {
        return ReconciliationResult(didChange: didChange, succeeded: false)
      }

      do {
        if try await resumePendingPublicationIfNeeded() {
          didChange = true
        } else if try await reduceApplyAndReplicate() {
          didChange = true
        }
      } catch is CancellationError {
        requiresSuccessfulReconciliation = true
        return ReconciliationResult(didChange: didChange, succeeded: false)
      } catch {
        requiresSuccessfulReconciliation = true
        logError(error, "Failed to reconcile shared-session owner slots")
        return ReconciliationResult(didChange: didChange, succeeded: false)
      }
    } while reconcileAgain

    requiresSuccessfulReconciliation = false
    return ReconciliationResult(didChange: didChange, succeeded: true)
  }

  @discardableResult
  private func reduceApplyAndReplicateSynchronously() throws -> Bool {
    guard let clerk, isCurrent(clerk: clerk), !isLocalClearInProgress else {
      return false
    }
    guard try localIdentityStore.loadPendingPublication() == nil else {
      return false
    }

    let slots = try slotStore.loadAllSlots()
    let reduction = SharedSessionIdentityReducer.reduce(slots)
    currentMaximumGeneration = max(
      currentMaximumGeneration,
      reduction.maximumGeneration
    )

    guard let winner = reduction.winner else {
      if let identity = try localIdentityStore.load() {
        currentDeviceToken = identity.deviceToken
      }
      return false
    }
    requiresSuccessfulReconciliation = true

    let identity = try ClerkIdentitySnapshot(
      state: winner.state,
      deviceToken: winner.deviceToken,
      client: winner.client,
      serverDate: winner.serverDate
    ).validated()

    let ownSlot = slots.first { $0.slotOwnerIdentifier == ownerIdentifier }
    if ownSlot?.event != winner {
      _ = try replicateOwnIfCompatibleSynchronously(winner)
    }

    try localIdentityStore.save(identity)

    let previousAcceptedEventID = acceptedEventID
    let didChange = winner.id != previousAcceptedEventID
    if didChange {
      applyToMemory(winner, clerk: clerk)
    }
    updateNetworkResponseLineage(
      winner: winner,
      previousAcceptedEventID: previousAcceptedEventID,
      candidate: nil
    )
    requiresSuccessfulReconciliation = false
    return didChange
  }

  private func ensureSuccessfulReconciliationIfNeeded() async throws {
    guard requiresSuccessfulReconciliation else { return }
    let result = await runReconciliationLoop()
    guard result.succeeded else {
      throw SharedSessionSyncCoordinatorError.reconciliationFailed
    }
  }

  @discardableResult
  private func resumePendingPublicationIfNeeded() async throws -> Bool {
    guard let clerk, isCurrent(clerk: clerk), !isLocalClearInProgress else {
      throw CancellationError()
    }
    let recoveryRevision = operationRevision
    guard let pending = try await performCheckedOperation(
      revision: recoveryRevision,
      clerk: clerk,
      operation: {
        try await self.localIdentityIO.loadRecord()?.pendingPublication
      }
    ) else {
      return false
    }
    guard pending.originOwnerIdentifier == ownerIdentifier else {
      throw SharedSessionSyncCoordinatorError.pendingPublicationOwnerMismatch
    }

    let observedSlots = try await performCheckedOperation(
      revision: recoveryRevision,
      clerk: clerk
    ) {
      try await self.slotIO.loadAllSlots()
    }

    let prospectiveReduction = SharedSessionIdentityReducer.reduce(
      events: observedSlots.map(\.event) + [pending]
    )
    if prospectiveReduction.conflictingEventIDs.contains(pending.id) {
      try await performCheckedOperation(
        revision: recoveryRevision,
        clerk: clerk
      ) {
        try await self.localIdentityIO.clearPendingPublication()
      }
      return try await reduceApplyAndReplicate()
    }
    var pendingWasPeerVisible = observedSlots.contains {
      $0.slotOwnerIdentifier == ownerIdentifier && $0.event == pending
    }
    if prospectiveReduction.winner == pending, !pendingWasPeerVisible {
      do {
        try await performCheckedOperation(
          revision: recoveryRevision,
          clerk: clerk
        ) {
          try await self.saveOwn(pending)
        }
      } catch let error as SharedSessionOwnerSlotStoreError {
        guard case .futureSchemaVersion = error else { throw error }
        try await performCheckedOperation(
          revision: recoveryRevision,
          clerk: clerk
        ) {
          try await self.localIdentityIO.clearPendingPublication()
        }
        return try await reduceApplyAndReplicate()
      }
      pendingWasPeerVisible = true
    }

    try validateActiveOperation(recoveryRevision, clerk: clerk)
    let didChange = try await reduceApplyAndReplicate(
      clearingPendingPublicationID: pending.id
    )
    if pendingWasPeerVisible {
      notifier.post()
    }
    return didChange
  }

  @discardableResult
  private func reduceApplyAndReplicate(
    clearingPendingPublicationID pendingPublicationID: UUID? = nil,
    networkResponseCandidate: (eventID: UUID, rootGeneration: UInt64)? = nil
  ) async throws -> Bool {
    guard let clerk, isCurrent(clerk: clerk), !isLocalClearInProgress else {
      throw CancellationError()
    }
    let reductionRevision = operationRevision
    let slots = try await slotIO.loadAllSlots()
    do {
      try validateActiveOperation(reductionRevision, clerk: clerk)
    } catch {
      reconcileAgain = true
      throw error
    }

    let reduction = SharedSessionIdentityReducer.reduce(slots)
    currentMaximumGeneration = max(
      currentMaximumGeneration,
      reduction.maximumGeneration
    )
    guard let winner = reduction.winner else {
      if pendingPublicationID != nil {
        throw SharedSessionSyncCoordinatorError.missingWinnerForPendingPublication
      }
      return false
    }
    requiresSuccessfulReconciliation = true

    let identity = try ClerkIdentitySnapshot(
      state: winner.state,
      deviceToken: winner.deviceToken,
      client: winner.client,
      serverDate: winner.serverDate
    ).validated()

    let ownSlot = slots.first { $0.slotOwnerIdentifier == ownerIdentifier }
    if ownSlot?.event != winner {
      _ = try await performCheckedOperation(
        revision: reductionRevision,
        clerk: clerk
      ) {
        try await self.replicateOwnIfCompatible(winner)
      }
    }

    if let pendingPublicationID {
      try await performCheckedOperation(
        revision: reductionRevision,
        clerk: clerk
      ) {
        try await self.localIdentityIO.commitAcceptedIdentity(
          identity,
          clearingPendingPublicationID: pendingPublicationID
        )
      }
    } else {
      try await performCheckedOperation(
        revision: reductionRevision,
        clerk: clerk
      ) {
        try await self.localIdentityIO.saveAcceptedIdentity(identity)
      }
    }

    let previousAcceptedEventID = acceptedEventID
    let didChange = winner.id != previousAcceptedEventID
    if didChange {
      applyToMemory(winner, clerk: clerk)
    }
    updateNetworkResponseLineage(
      winner: winner,
      previousAcceptedEventID: previousAcceptedEventID,
      candidate: networkResponseCandidate
    )
    requiresSuccessfulReconciliation = false
    return didChange
  }

  private func applyToMemory(_ event: SharedSessionIdentityEvent, clerk: Clerk) {
    let previousToken = currentDeviceToken
    currentDeviceToken = event.deviceToken
    if previousToken != currentDeviceToken {
      responseOrderingGate.reset()
    }
    clerk.identityController.applySharedEvent(
      event,
      previousDeviceToken: previousToken
    )
    acceptedEventID = event.id
    currentMaximumGeneration = max(currentMaximumGeneration, event.generation)
  }

  private func saveOwn(_ event: SharedSessionIdentityEvent) async throws {
    try await slotIO.saveOwnSlot(
      SharedSessionOwnerSlot(
        schemaVersion: SharedSessionOwnerSlot.schemaVersion,
        instanceFingerprint: instanceFingerprint,
        slotOwnerIdentifier: ownerIdentifier,
        event: event
      )
    )
  }

  private func saveOwnSynchronously(_ event: SharedSessionIdentityEvent) throws {
    try slotStore.saveOwnSlot(
      SharedSessionOwnerSlot(
        schemaVersion: SharedSessionOwnerSlot.schemaVersion,
        instanceFingerprint: instanceFingerprint,
        slotOwnerIdentifier: ownerIdentifier,
        event: event
      )
    )
  }

  @discardableResult
  private func replicateOwnIfCompatible(_ event: SharedSessionIdentityEvent) async throws -> Bool {
    do {
      try await saveOwn(event)
      return true
    } catch let error as SharedSessionOwnerSlotStoreError {
      guard case .futureSchemaVersion = error else { throw error }
      return false
    }
  }

  @discardableResult
  private func replicateOwnIfCompatibleSynchronously(_ event: SharedSessionIdentityEvent) throws -> Bool {
    do {
      try saveOwnSynchronously(event)
      return true
    } catch let error as SharedSessionOwnerSlotStoreError {
      guard case .futureSchemaVersion = error else { throw error }
      return false
    }
  }

  private func enqueueSerializedOperation<T: Sendable>(
    _ operation: @escaping @MainActor @Sendable () async throws -> T
  ) -> Task<T, Error> {
    let predecessor = serializedOperationTail
    let task = Task { @MainActor in
      _ = await predecessor?.value
      try Task.checkCancellation()
      return try await operation()
    }
    serializedOperationTail = Task { @MainActor in
      _ = await task.result
    }
    return task
  }

  private func isCurrent(clerk: Clerk) -> Bool {
    isInstalled
      && !Task.isCancelled
      && clerk.sharedSessionSyncCoordinator === self
      && clerk.isCurrentConfigurationEpoch(configurationEpoch)
  }

  private func validateActiveOperation(
    _ revision: UInt64,
    clerk: Clerk
  ) throws {
    guard isCurrent(clerk: clerk),
          !isLocalClearInProgress,
          revision == operationRevision
    else {
      throw CancellationError()
    }
  }

  private func performCheckedOperation<T>(
    revision: UInt64,
    clerk: Clerk,
    operation: @MainActor () async throws -> T,
    didComplete: @MainActor () -> Void = {}
  ) async throws -> T {
    try validateActiveOperation(revision, clerk: clerk)
    let result = try await operation()
    didComplete()
    try validateActiveOperation(revision, clerk: clerk)
    return result
  }

  private func canScheduleRecovery(clerk: Clerk) -> Bool {
    isInstalled
      && !isLocalClearInProgress
      && clerk.sharedSessionSyncCoordinator === self
      && clerk.isCurrentConfigurationEpoch(configurationEpoch)
  }
}

extension SharedSessionSyncCoordinator {
  private func responseCanBeAccepted(
    sequence: Int?,
    serverDate: Date?,
    incomingClient: Client?,
    currentClient: Client?
  ) -> Bool {
    responseOrderingGate.accepts(
      sequence: sequence,
      serverDate: serverDate,
      incomingUpdatedAt: incomingClient?.updatedAt,
      currentUpdatedAt: currentClient?.updatedAt
    )
  }

  private func checkpointAllowsPublication(_ checkpoint: PublicationCheckpoint) -> Bool {
    switch checkpoint {
    case .none:
      true
    case let .response(baseGeneration, requestDeviceToken):
      responseCanPublish(
        from: baseGeneration,
        requestDeviceToken: requestDeviceToken
      )
    }
  }

  private func responseCanPublish(
    from baseGeneration: UInt64,
    requestDeviceToken: String?
  ) -> Bool {
    guard requestDeviceToken == currentDeviceToken else { return false }
    if baseGeneration == currentMaximumGeneration {
      return true
    }
    guard let networkResponseLineage else { return false }
    return baseGeneration >= networkResponseLineage.rootGeneration
      && baseGeneration <= networkResponseLineage.frontierGeneration
      && networkResponseLineage.frontierGeneration == currentMaximumGeneration
      && networkResponseLineage.deviceToken == currentDeviceToken
  }

  private func networkResponseCandidate(
    for checkpoint: PublicationCheckpoint,
    eventID: UUID
  ) -> (eventID: UUID, rootGeneration: UInt64)? {
    guard case .response(let baseGeneration, _) = checkpoint else { return nil }
    return (eventID, baseGeneration)
  }

  private func updateNetworkResponseLineage(
    winner: SharedSessionIdentityEvent,
    previousAcceptedEventID: UUID?,
    candidate: (eventID: UUID, rootGeneration: UInt64)?
  ) {
    if let candidate, winner.id == candidate.eventID {
      let rootGeneration = if let networkResponseLineage,
                              networkResponseLineage.deviceToken == currentDeviceToken,
                              networkResponseLineage.frontierGeneration < winner.generation,
                              candidate.rootGeneration >= networkResponseLineage.rootGeneration,
                              candidate.rootGeneration <= networkResponseLineage.frontierGeneration
      {
        networkResponseLineage.rootGeneration
      } else {
        candidate.rootGeneration
      }
      networkResponseLineage = NetworkResponseLineage(
        rootGeneration: rootGeneration,
        frontierGeneration: winner.generation,
        deviceToken: currentDeviceToken
      )
    } else if candidate != nil || winner.id != previousAcceptedEventID {
      networkResponseLineage = nil
    }
  }
}
