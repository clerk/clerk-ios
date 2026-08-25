//
//  SharedSessionSyncCoordinator.swift
//  Clerk
//

// swiftlint:disable file_length

import Foundation

enum SharedSessionClientPresentationPolicy {
  case replaceWithIdentity
  case preserveProvisional
}

enum SharedSessionSyncCoordinatorError: Error, Equatable {
  case initialReconciliationFailed
  case reconciliationFailed
  case missingWinnerForPendingPublication
  case pendingPublicationOwnerMismatch
}

@MainActor
final class SharedSessionSyncCoordinator: ClerkInternalStateChangeObserver {
  struct NetworkResponseOutcome: Equatable {
    enum ResponseIdentityDisposition: Equatable {
      case applied
      case superseded
      case ignored
    }

    let responseIdentity: ResponseIdentityDisposition
    let completion: AuthFlowCompletionDisposition
  }

  enum PublicationCheckpoint {
    case none
    case response(
      baseGeneration: UInt64,
      requestDeviceToken: String?
    )
  }

  private struct AuthFlowCompletionCandidate {
    let eventId: UUID
    let flow: TransferFlowResult
    let ownerId: UUID
  }

  struct NetworkResponseLineage {
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
  private(set) var initialHydrationError: (any Error)?
  var responseOrderingGate = ClientResponseOrderingGate()
  var networkResponseLineage: NetworkResponseLineage?
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
    startupClientRefreshTakeoverID: UUID? = nil,
    authFlowRegistrationId: UUID? = nil
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
        startupClientRefreshTakeoverID: startupClientRefreshTakeoverID,
        authFlowRegistrationId: authFlowRegistrationId
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
}

extension SharedSessionSyncCoordinator {
  @discardableResult
  func hydrateInitialSharedState() -> Bool {
    guard initialReconciliationTask == nil,
          reconciliationTask == nil,
          serializedOperationTail == nil
    else {
      return false
    }

    initialHydrationError = nil
    do {
      if let record = try localIdentityStore.loadRecord(),
         record.pendingPublication != nil
         || record.requiresSharedSessionPublication
      {
        _ = try slotStore.loadAllSlots()
        if record.requiresSharedSessionPublication,
           let identity = record.acceptedIdentity
        {
          currentDeviceToken = identity.deviceToken
          clerk?.identityController.hydrateAtomicIdentityIfNeeded(identity)
        }
        requiresSuccessfulReconciliation = true
        return false
      }
      return try reduceApplyAndReplicateSynchronously()
    } catch {
      initialHydrationError = error
      requiresSuccessfulReconciliation = true
      logError(error, "Failed to hydrate initial shared-session owner slots")
      return false
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
        } else if try await publishRequiredLocalIdentityIfNeeded() {
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

  private func canScheduleRecovery(clerk: Clerk) -> Bool {
    isInstalled
      && !isLocalClearInProgress
      && clerk.sharedSessionSyncCoordinator === self
      && clerk.isCurrentConfigurationEpoch(configurationEpoch)
  }
}

extension SharedSessionSyncCoordinator {
  private struct Publication {
    let state: SharedSessionIdentityEvent.State
    let deviceToken: String?
    let client: Client?
    let serverDate: Date?
    let baseGeneration: UInt64?
    let checkpoint: PublicationCheckpoint
    let clientPresentationPolicy: SharedSessionClientPresentationPolicy
    let completedAuthFlow: TransferFlowResult?
    let authFlowRegistrationId: UUID?

    init(
      state: SharedSessionIdentityEvent.State,
      deviceToken: String?,
      client: Client?,
      serverDate: Date?,
      baseGeneration: UInt64?,
      checkpoint: PublicationCheckpoint,
      clientPresentationPolicy: SharedSessionClientPresentationPolicy,
      completedAuthFlow: TransferFlowResult? = nil,
      authFlowRegistrationId: UUID? = nil
    ) {
      self.state = state
      self.deviceToken = deviceToken
      self.client = client
      self.serverDate = serverDate
      self.baseGeneration = baseGeneration
      self.checkpoint = checkpoint
      self.clientPresentationPolicy = clientPresentationPolicy
      self.completedAuthFlow = completedAuthFlow
      self.authFlowRegistrationId = authFlowRegistrationId
    }
  }

  private struct PreparedPublication {
    let publication: Publication
    let event: SharedSessionIdentityEvent
    let completionCandidate: AuthFlowCompletionCandidate?
    let revision: UInt64
    let clerk: Clerk
  }

  @discardableResult
  func handleNetworkResponse(
    _ context: ClientSyncResponseContext
  ) async throws -> NetworkResponseOutcome {
    let task: Task<NetworkResponseOutcome, Error> = enqueueSerializedOperation { [weak self] in
      guard let self else { throw CancellationError() }
      var didResolvePublication = false
      let didApply = try await performPublication {
        try resolveNetworkResponsePublication(
          context,
          didResolvePublication: &didResolvePublication
        )
      }
      if didApply {
        responseOrderingGate.record(
          sequence: context.responseSequence,
          serverDate: context.serverDate
        )
      }

      let responseIdentity: NetworkResponseOutcome.ResponseIdentityDisposition = if didApply {
        .applied
      } else if didResolvePublication {
        .superseded
      } else {
        .ignored
      }
      let completion: AuthFlowCompletionDisposition = if let completedAuthFlow = context.completedAuthFlow {
        if didApply {
          .accepted
        } else {
          AuthFlowIdentityUpdate.completionDisposition(
            for: completedAuthFlow,
            authoritativeClient: clerk?.authoritativeClient
          )
        }
      } else {
        .absent
      }
      return NetworkResponseOutcome(
        responseIdentity: responseIdentity,
        completion: completion
      )
    }
    return try await withTaskCancellationHandler {
      try await task.value
    } onCancel: {
      task.cancel()
    }
  }

  private func resolveNetworkResponsePublication(
    _ context: ClientSyncResponseContext,
    didResolvePublication: inout Bool
  ) throws -> Publication? {
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
    didResolvePublication = true
    return Publication(
      state: identity.state,
      deviceToken: identity.deviceToken,
      client: identity.client,
      serverDate: identity.serverDate,
      baseGeneration: nil,
      checkpoint: .response(
        baseGeneration: baseGeneration,
        requestDeviceToken: context.requestDeviceToken
      ),
      clientPresentationPolicy: .replaceWithIdentity,
      completedAuthFlow: context.completedAuthFlow,
      authFlowRegistrationId: context.authFlowRegistrationId
    )
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
        checkpoint: .none,
        clientPresentationPolicy: .replaceWithIdentity
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
        checkpoint: .none,
        clientPresentationPolicy: .replaceWithIdentity
      )
    )
  }

  private func publishRequiredLocalIdentityIfNeeded() async throws -> Bool {
    guard let clerk, isCurrent(clerk: clerk), !isLocalClearInProgress else {
      throw CancellationError()
    }
    let preparationRevision = operationRevision
    guard let record = try await performCheckedOperation(
      revision: preparationRevision,
      clerk: clerk,
      operation: {
        try await self.localIdentityIO.loadRecord()
      }
    ),
      record.requiresSharedSessionPublication,
      let identity = record.acceptedIdentity
    else {
      return false
    }

    let slots = try await performCheckedOperation(
      revision: preparationRevision,
      clerk: clerk
    ) {
      try await self.slotIO.loadAllSlots()
    }
    currentMaximumGeneration = max(
      currentMaximumGeneration,
      SharedSessionIdentityReducer.reduce(slots).maximumGeneration
    )

    return try await performPublication(
      Publication(
        state: identity.state,
        deviceToken: identity.deviceToken,
        client: identity.client,
        serverDate: identity.serverDate,
        baseGeneration: currentMaximumGeneration,
        checkpoint: .none,
        clientPresentationPolicy: identity.state == .cleared
          && identity.deviceToken.nilIfEmpty != nil
          ? .preserveProvisional
          : .replaceWithIdentity
      ),
      ensuringSuccessfulReconciliation: false
    )
  }

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

  private func performPublication(
    _ publication: Publication,
    ensuringSuccessfulReconciliation: Bool = true
  ) async throws -> Bool {
    try await performPublication(
      ensuringSuccessfulReconciliation: ensuringSuccessfulReconciliation
    ) { publication }
  }

  private func performPublication(
    ensuringSuccessfulReconciliation: Bool = true,
    resolve: @MainActor () throws -> Publication?
  ) async throws -> Bool {
    guard let prepared = try await preparePublication(
      ensuringSuccessfulReconciliation: ensuringSuccessfulReconciliation,
      resolve: resolve
    ) else {
      return false
    }

    var didStage = false
    do {
      try await performCheckedOperation(
        revision: prepared.revision,
        clerk: prepared.clerk,
        operation: {
          try await self.localIdentityIO.stagePendingPublication(prepared.event)
        },
        didComplete: {
          didStage = true
          self.requiresSuccessfulReconciliation = true
        }
      )
      guard try await saveOrResolveFutureSchemaPublication(
        prepared,
        didClearPending: { didStage = false }
      ) else {
        return false
      }
      try await commitPublication(prepared)
      notifier.post()
      return acceptedEventID == prepared.event.id
    } catch {
      if didStage, canScheduleRecovery(clerk: prepared.clerk) {
        requestReconciliation()
      }
      throw error
    }
  }

  private func preparePublication(
    ensuringSuccessfulReconciliation: Bool,
    resolve: @MainActor () throws -> Publication?
  ) async throws -> PreparedPublication? {
    guard let clerk, isCurrent(clerk: clerk), !isLocalClearInProgress else {
      throw CancellationError()
    }
    if ensuringSuccessfulReconciliation {
      try await ensureSuccessfulReconciliationIfNeeded()
    }
    _ = try await resumePendingPublicationIfNeeded()
    guard let publication = try resolve(),
          isCurrent(clerk: clerk),
          !isLocalClearInProgress,
          checkpointAllowsPublication(publication.checkpoint)
    else {
      return nil
    }

    operationRevision &+= 1
    let revision = operationRevision
    let event = try SharedSessionIdentityEvent(
      id: UUID(),
      originOwnerIdentifier: ownerIdentifier,
      generation: SharedSessionIdentityEvent.nextGeneration(
        after: publication.baseGeneration ?? currentMaximumGeneration
      ),
      state: publication.state,
      deviceToken: publication.deviceToken.nilIfEmpty,
      client: publication.client,
      serverDate: publication.serverDate
    ).validated()
    let completionCandidate: AuthFlowCompletionCandidate? = if let completedAuthFlow = publication.completedAuthFlow,
                                                               let ownerId = publication.authFlowRegistrationId
    {
      AuthFlowCompletionCandidate(
        eventId: event.id,
        flow: completedAuthFlow,
        ownerId: ownerId
      )
    } else {
      nil
    }
    return PreparedPublication(
      publication: publication,
      event: event,
      completionCandidate: completionCandidate,
      revision: revision,
      clerk: clerk
    )
  }

  private func saveOrResolveFutureSchemaPublication(
    _ prepared: PreparedPublication,
    didClearPending: @MainActor () -> Void
  ) async throws -> Bool {
    do {
      try await performCheckedOperation(
        revision: prepared.revision,
        clerk: prepared.clerk
      ) {
        try await self.saveOwn(prepared.event)
      }
      return true
    } catch let error as SharedSessionOwnerSlotStoreError {
      guard case .futureSchemaVersion = error else { throw error }
      if let candidate = prepared.completionCandidate {
        _ = try await reduceApplyAndReplicate(
          clearingPendingPublicationID: prepared.event.id,
          completedAuthFlowCandidate: candidate
        )
      } else {
        try await performCheckedOperation(
          revision: prepared.revision,
          clerk: prepared.clerk,
          operation: {
            try await self.localIdentityIO.clearPendingPublication()
          },
          didComplete: didClearPending
        )
        _ = try await reduceApplyAndReplicate()
      }
      return false
    }
  }

  private func commitPublication(_ prepared: PreparedPublication) async throws {
    _ = try await performCheckedOperation(
      revision: prepared.revision,
      clerk: prepared.clerk
    ) {
      try await self.reduceApplyAndReplicate(
        clearingPendingPublicationID: prepared.event.id,
        networkResponseCandidate: self.networkResponseCandidate(
          for: prepared.publication.checkpoint,
          eventID: prepared.event.id
        ),
        provisionalClientPreservingEventID: prepared.publication.clientPresentationPolicy
          == .preserveProvisional ? prepared.event.id : nil,
        completedAuthFlowCandidate: prepared.completionCandidate
      )
    }
  }
}

extension SharedSessionSyncCoordinator {
  private struct PendingRecovery {
    let clerk: Clerk
    let revision: UInt64
    let event: SharedSessionIdentityEvent
    let provisionalClientPreservingEventID: UUID?
  }

  private enum PendingVisibilityResult {
    case visible(shouldNotify: Bool)
    case resolved(didChange: Bool)
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
    guard let recovery = try await loadPendingRecovery() else { return false }
    let observedSlots = try await performCheckedOperation(
      revision: recovery.revision,
      clerk: recovery.clerk
    ) {
      try await self.slotIO.loadAllSlots()
    }
    let prospectiveReduction = SharedSessionIdentityReducer.reduce(
      events: observedSlots.map(\.event) + [recovery.event]
    )
    if prospectiveReduction.conflictingEventIDs.contains(recovery.event.id) {
      return try await resolvePendingWithoutOwnSlot(recovery)
    }
    switch try await ensurePendingIsPeerVisible(
      recovery,
      observedSlots: observedSlots,
      prospectiveWinner: prospectiveReduction.winner
    ) {
    case .resolved(let didChange):
      return didChange
    case .visible(let shouldNotify):
      return try await finishPendingRecovery(
        recovery,
        shouldNotify: shouldNotify
      )
    }
  }

  private func loadPendingRecovery() async throws -> PendingRecovery? {
    guard let clerk, isCurrent(clerk: clerk), !isLocalClearInProgress else {
      throw CancellationError()
    }
    let revision = operationRevision
    guard let record = try await performCheckedOperation(
      revision: revision,
      clerk: clerk,
      operation: {
        try await self.localIdentityIO.loadRecord()
      }
    ), let pending = record.pendingPublication else {
      return nil
    }
    guard pending.originOwnerIdentifier == ownerIdentifier else {
      throw SharedSessionSyncCoordinatorError.pendingPublicationOwnerMismatch
    }
    return PendingRecovery(
      clerk: clerk,
      revision: revision,
      event: pending,
      provisionalClientPreservingEventID: record.pendingTokenOnlyPublicationEventID(
        for: ownerIdentifier
      )
    )
  }

  private func ensurePendingIsPeerVisible(
    _ recovery: PendingRecovery,
    observedSlots: [SharedSessionOwnerSlot],
    prospectiveWinner: SharedSessionIdentityEvent?
  ) async throws -> PendingVisibilityResult {
    let isPeerVisible = observedSlots.contains {
      $0.slotOwnerIdentifier == ownerIdentifier && $0.event == recovery.event
    }
    guard prospectiveWinner == recovery.event, !isPeerVisible else {
      return .visible(shouldNotify: isPeerVisible)
    }
    do {
      try await performCheckedOperation(
        revision: recovery.revision,
        clerk: recovery.clerk
      ) {
        try await self.saveOwn(recovery.event)
      }
      return .visible(shouldNotify: true)
    } catch let error as SharedSessionOwnerSlotStoreError {
      guard case .futureSchemaVersion = error else { throw error }
      let didChange = try await resolvePendingWithoutOwnSlot(recovery)
      return .resolved(didChange: didChange)
    }
  }

  private func resolvePendingWithoutOwnSlot(
    _ recovery: PendingRecovery
  ) async throws -> Bool {
    try await performCheckedOperation(
      revision: recovery.revision,
      clerk: recovery.clerk
    ) {
      try await self.localIdentityIO.clearPendingPublication()
    }
    return try await reduceApplyAndReplicate()
  }

  private func finishPendingRecovery(
    _ recovery: PendingRecovery,
    shouldNotify: Bool
  ) async throws -> Bool {
    try validateActiveOperation(recovery.revision, clerk: recovery.clerk)
    let didChange = try await reduceApplyAndReplicate(
      clearingPendingPublicationID: recovery.event.id,
      provisionalClientPreservingEventID: recovery.provisionalClientPreservingEventID
    )
    if shouldNotify {
      notifier.post()
    }
    return didChange
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
}

extension SharedSessionSyncCoordinator {
  private struct PreparedReduction {
    let clerk: Clerk
    let revision: UInt64
    let slots: [SharedSessionOwnerSlot]
    let winner: SharedSessionIdentityEvent?
    let completionCandidate: AuthFlowCompletionCandidate?
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
      applyToMemory(
        winner,
        clerk: clerk,
        authFlowUpdate: .authoritativeIdentityChanged
      )
    }
    updateNetworkResponseLineage(
      winner: winner,
      previousAcceptedEventID: previousAcceptedEventID,
      candidate: nil
    )
    requiresSuccessfulReconciliation = false
    return didChange
  }

  @discardableResult
  private func reduceApplyAndReplicate(
    clearingPendingPublicationID pendingPublicationID: UUID? = nil,
    networkResponseCandidate: (eventID: UUID, rootGeneration: UInt64)? = nil,
    provisionalClientPreservingEventID: UUID? = nil,
    completedAuthFlowCandidate: AuthFlowCompletionCandidate? = nil
  ) async throws -> Bool {
    let prepared = try await prepareReduction(
      completionCandidate: completedAuthFlowCandidate
    )
    guard let winner = prepared.winner else {
      return try await resolveMissingWinner(
        prepared,
        pendingPublicationID: pendingPublicationID
      )
    }
    requiresSuccessfulReconciliation = true
    let identity = try ClerkIdentitySnapshot(
      state: winner.state,
      deviceToken: winner.deviceToken,
      client: winner.client,
      serverDate: winner.serverDate
    ).validated()
    try await persistReductionWinner(
      winner,
      identity: identity,
      prepared: prepared,
      pendingPublicationID: pendingPublicationID
    )
    return finishReduction(
      winner,
      prepared: prepared,
      networkResponseCandidate: networkResponseCandidate,
      provisionalClientPreservingEventID: provisionalClientPreservingEventID
    )
  }

  private func prepareReduction(
    completionCandidate: AuthFlowCompletionCandidate?
  ) async throws -> PreparedReduction {
    guard let clerk, isCurrent(clerk: clerk), !isLocalClearInProgress else {
      throw CancellationError()
    }
    let revision = operationRevision
    let slots = try await slotIO.loadAllSlots()
    do {
      try validateActiveOperation(revision, clerk: clerk)
    } catch {
      reconcileAgain = true
      throw error
    }
    let reduction = SharedSessionIdentityReducer.reduce(slots)
    currentMaximumGeneration = max(
      currentMaximumGeneration,
      reduction.maximumGeneration
    )
    return PreparedReduction(
      clerk: clerk,
      revision: revision,
      slots: slots,
      winner: reduction.winner,
      completionCandidate: completionCandidate
    )
  }

  private func resolveMissingWinner(
    _ prepared: PreparedReduction,
    pendingPublicationID: UUID?
  ) async throws -> Bool {
    guard let candidate = prepared.completionCandidate else {
      if pendingPublicationID != nil {
        throw SharedSessionSyncCoordinatorError.missingWinnerForPendingPublication
      }
      return false
    }
    if pendingPublicationID != nil {
      try await performCheckedOperation(
        revision: prepared.revision,
        clerk: prepared.clerk
      ) {
        try await self.localIdentityIO.clearPendingPublication()
      }
    }
    prepared.clerk.resolveAuthFlowCompletion(
      .resolvingSupersededCompletion(
        candidate.flow,
        ownerId: candidate.ownerId,
        authoritativeClient: prepared.clerk.authoritativeClient
      )
    )
    return false
  }

  private func persistReductionWinner(
    _ winner: SharedSessionIdentityEvent,
    identity: ClerkIdentitySnapshot,
    prepared: PreparedReduction,
    pendingPublicationID: UUID?
  ) async throws {
    let ownSlot = prepared.slots.first {
      $0.slotOwnerIdentifier == ownerIdentifier
    }
    if ownSlot?.event != winner {
      _ = try await performCheckedOperation(
        revision: prepared.revision,
        clerk: prepared.clerk
      ) {
        try await self.replicateOwnIfCompatible(winner)
      }
    }
    if let pendingPublicationID {
      try await performCheckedOperation(
        revision: prepared.revision,
        clerk: prepared.clerk
      ) {
        try await self.localIdentityIO.commitAcceptedIdentity(
          identity,
          clearingPendingPublicationID: pendingPublicationID
        )
      }
    } else {
      try await performCheckedOperation(
        revision: prepared.revision,
        clerk: prepared.clerk
      ) {
        try await self.localIdentityIO.saveAcceptedIdentity(identity)
      }
    }
  }

  private func finishReduction(
    _ winner: SharedSessionIdentityEvent,
    prepared: PreparedReduction,
    networkResponseCandidate: (eventID: UUID, rootGeneration: UInt64)?,
    provisionalClientPreservingEventID: UUID?
  ) -> Bool {
    let previousAcceptedEventID = acceptedEventID
    let didChange = winner.id != previousAcceptedEventID
    let authFlowUpdate = reductionAuthFlowUpdate(
      winner: winner,
      candidate: prepared.completionCandidate,
      authoritativeIdentityChanged: didChange
    )
    if didChange || prepared.completionCandidate != nil {
      applyToMemory(
        winner,
        clerk: prepared.clerk,
        clientPresentationPolicy: winner.id == provisionalClientPreservingEventID
          ? .preserveProvisional
          : .replaceWithIdentity,
        authFlowUpdate: authFlowUpdate
      )
    }
    updateNetworkResponseLineage(
      winner: winner,
      previousAcceptedEventID: previousAcceptedEventID,
      candidate: networkResponseCandidate
    )
    requiresSuccessfulReconciliation = false
    return didChange
  }

  private func reductionAuthFlowUpdate(
    winner: SharedSessionIdentityEvent,
    candidate: AuthFlowCompletionCandidate?,
    authoritativeIdentityChanged: Bool
  ) -> AuthFlowIdentityUpdate {
    guard let candidate else {
      return authoritativeIdentityChanged ? .authoritativeIdentityChanged : .ordinary
    }
    if candidate.eventId == winner.id {
      return .completionAccepted(
        candidate.flow,
        ownerId: candidate.ownerId,
        authoritativeIdentityChanged: authoritativeIdentityChanged
      )
    }
    return .resolvingSupersededCompletion(
      candidate.flow,
      ownerId: candidate.ownerId,
      authoritativeClient: winner.client,
      authoritativeIdentityChanged: authoritativeIdentityChanged
    )
  }

  private func applyToMemory(
    _ event: SharedSessionIdentityEvent,
    clerk: Clerk,
    clientPresentationPolicy: SharedSessionClientPresentationPolicy = .replaceWithIdentity,
    authFlowUpdate: AuthFlowIdentityUpdate = .ordinary
  ) {
    let previousToken = currentDeviceToken
    currentDeviceToken = event.deviceToken
    if previousToken != currentDeviceToken {
      responseOrderingGate.reset()
    }
    clerk.identityController.applySharedEvent(
      event,
      previousDeviceToken: previousToken,
      clientPresentationPolicy: clientPresentationPolicy,
      authFlowUpdate: authFlowUpdate
    )
    acceptedEventID = event.id
    currentMaximumGeneration = max(currentMaximumGeneration, event.generation)
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
  private func replicateOwnIfCompatible(
    _ event: SharedSessionIdentityEvent
  ) async throws -> Bool {
    do {
      try await saveOwn(event)
      return true
    } catch let error as SharedSessionOwnerSlotStoreError {
      guard case .futureSchemaVersion = error else { throw error }
      return false
    }
  }

  @discardableResult
  private func replicateOwnIfCompatibleSynchronously(
    _ event: SharedSessionIdentityEvent
  ) throws -> Bool {
    do {
      try saveOwnSynchronously(event)
      return true
    } catch let error as SharedSessionOwnerSlotStoreError {
      guard case .futureSchemaVersion = error else { throw error }
      return false
    }
  }
}
