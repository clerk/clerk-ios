//
//  ClerkIdentityController.swift
//  Clerk
//

// swiftlint:disable file_length

import Foundation

/// Owns Clerk's in-memory identity and its single persisted record.
///
/// Every identity change goes through ``commit(_:fenceResponses:authFlowUpdate:)``,
/// which writes the device token, Client, and server date to ``ClerkIdentityStore``
/// together before updating memory.
///
/// With shared-session sync, other apps write the same record. Before using or
/// replacing the identity, the controller re-reads the record and adopts it if its
/// revision changed, and after writing it notifies the other apps.
@MainActor
final class ClerkIdentityController {
  struct RollbackState {
    let lastAppliedResponseSequence: Int?
    let lastServerDate: Date?
  }

  struct ExternalTransition {
    let identity: ClerkIdentitySnapshot
    var fenceAllClientResponses = true
    var watchClearGeneration: Int?
    /// A clear can arrive with a refreshed token/Client instead of a tokenless snapshot.
    var recordsClear = false
    var didApply: @MainActor () -> Void = {}
  }

  weak var clerk: Clerk?

  private(set) var currentDeviceToken: String?
  private var storedRecord: ClerkIdentityStore.Record?
  private var clearPending = false
  private var hydrationError: (any Error)?
  private var notifier: (any SharedSessionSyncNotifying)?

  private(set) var clientResponseGeneration: ClientResponseGeneration = .initial
  private var responseOrderingGate = ClientResponseOrderingGate()
  var lastServerDate: Date? {
    get { responseOrderingGate.lastAcceptedServerDate }
    set { responseOrderingGate.lastAcceptedServerDate = newValue }
  }

  init(clerk: Clerk) {
    self.clerk = clerk
  }

  var authoritativeClient: Client? {
    clerk?.client
  }

  var isSharingIdentity: Bool {
    notifier != nil
  }

  /// Unavailable credentials and unfinished clears must not be published as a known identity.
  var canPublishIdentity: Bool {
    hydrationError == nil && !clearPending
  }

  private var store: ClerkIdentityStore? {
    clerk?.dependencies.identityStore
  }
}

// MARK: - Lifecycle

extension ClerkIdentityController {
  func prepareForConfiguration() {
    stopSharing()
    clearPending = false
    hydrationError = nil
    currentDeviceToken = nil
    storedRecord = nil
  }

  /// Loads the complete persisted identity during configuration or hydration recovery.
  func hydrate() {
    guard let clerk, let store else { return }
    let record: ClerkIdentityStore.Record?
    do {
      try store.prepareForUse()
      try store.recoverPendingClear()
      record = try store.load()
      try observeWatchClear(record)
      clearPending = false
      hydrationError = nil
    } catch ClerkIdentityStoreError.otherInstance {
      return
    } catch {
      hydrationError = error
      currentDeviceToken = nil
      ClerkLogger.logError(error, message: "Failed to load the persisted Clerk identity")
      return
    }
    storedRecord = record
    // Storage layout may have resolved only now, after a failed launch-time read.
    defer { clerk.startSharedSessionSyncIfNeeded(dependencies: clerk.dependencies) }
    guard let identity = record?.identity else { return }
    // A persisted record is one complete identity, including a nil Client. Keeping
    // an existing Client here can pair a sibling's token with the previous login.
    currentDeviceToken = identity.deviceToken
    lastServerDate = identity.serverDate
    clerk.setClientFromIdentityController(identity.client, authFlowUpdate: .authoritativeIdentityChanged)
  }

  /// Shares the identity with other apps in the access group.
  func startSharing(notifier: any SharedSessionSyncNotifying) {
    self.notifier = notifier
    notifier.setHandler { [weak self] in
      _ = self?.reconcileWithStore()
    }
    // Migration and crash recovery may have written before notifications started.
    notifier.post()
  }

  func stopSharing() {
    notifier?.setHandler {}
    notifier = nil
  }

  func captureRollbackState() -> RollbackState {
    RollbackState(
      lastAppliedResponseSequence: responseOrderingGate.lastAcceptedSequence,
      lastServerDate: lastServerDate
    )
  }

  func restoreRollbackState(_ state: RollbackState) {
    responseOrderingGate = ClientResponseOrderingGate(
      lastAcceptedSequence: state.lastAppliedResponseSequence,
      lastAcceptedServerDate: state.lastServerDate
    )
    // Rollback restores the runtime epoch, but the shared identity may have changed
    // during cleanup. Responses prepared before reconfiguration must stay fenced.
    fenceClientResponses()
  }

  func resetOrderingState() {
    responseOrderingGate.reset()
  }

  func resetRuntimeIdentity() {
    guard let clerk else { return }
    currentDeviceToken = nil
    storedRecord = nil
    lastServerDate = nil
    clerk.setClientFromIdentityController(nil)
  }

  func fenceClientResponses() {
    clientResponseGeneration = clientResponseGeneration.next()
    responseOrderingGate.resetSequence()
  }

  func persistedClientID() -> String? {
    try? store?.load()?.identity.client?.id
  }
}

// MARK: - Reading and Reloading

extension ClerkIdentityController {
  /// Adopts the persisted identity if another process wrote it since this app last read or wrote it.
  ///
  /// - Returns: `true` when the in-memory identity changed.
  @discardableResult
  func reconcileWithStore() -> Bool {
    do {
      return try reconcile()
    } catch {
      ClerkLogger.logError(error, message: "Failed to read the shared Clerk identity")
      return false
    }
  }

  @discardableResult
  private func reconcile() throws -> Bool {
    try ensureHydrated()
    guard !clearPending else { throw ClerkIdentityStoreError.clearPending }
    guard let store else { return false }
    let record = try store.load()
    guard record?.revision != storedRecord?.revision else { return false }
    try observeWatchClear(record)
    let epochChanged = record?.epoch != storedRecord?.epoch
    storedRecord = record
    let identity = record?.identity ?? .signedOut
    apply(identity, fenceResponses: epochChanged, authFlowUpdate: .authoritativeIdentityChanged)
    if !epochChanged {
      responseOrderingGate.adoptExternalSnapshot(serverDate: identity.serverDate)
    }
    return true
  }

  private func ensureHydrated() throws {
    guard hydrationError != nil else { return }
    hydrate()
    if let hydrationError { throw hydrationError }
  }

  func reloadPersistedState() async -> Bool {
    guard let clerk else { return false }
    let identityChanged = reconcileWithStore()
    return reloadPersistedEnvironment(in: clerk) || identityChanged
  }

  func captureRequestIdentity(
    startupClientRefreshTakeoverID: UUID? = nil
  ) async throws -> ClerkIdentityRequestSnapshot {
    guard let clerk else { throw CancellationError() }
    try ensureHydrated()
    guard !clearPending else { throw ClerkIdentityStoreError.clearPending }
    if isSharingIdentity {
      try reconcile()
    }
    clerk.startupClientRefreshTakeover.beginIfNeeded(
      id: startupClientRefreshTakeoverID,
      deviceToken: currentDeviceToken
    )
    return ClerkIdentityRequestSnapshot(
      deviceToken: currentDeviceToken,
      clientID: clerk.client?.id,
      clientResponseGeneration: clientResponseGeneration,
      authFlowRegistrationId: AuthFlowRequestScope.ownerId
    )
  }

  private func reloadPersistedEnvironment(in clerk: Clerk) -> Bool {
    do {
      guard let data = try clerk.dependencies.appLocalKeychain.data(
        forKey: ClerkKeychainKey.cachedEnvironment.rawValue
      ) else {
        return false
      }
      let environment = try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: data)
      guard environment != clerk.environment else { return false }
      clerk.environment = environment
      return true
    } catch {
      ClerkLogger.logError(error, message: "Failed to reload the cached Clerk environment")
      return false
    }
  }
}

// MARK: - Identity Changes

extension ClerkIdentityController {
  /// Applies a complete identity decided by another component, such as Watch sync.
  /// `prepare` sees the latest shared identity and may decline by returning `nil`.
  func applyExternalTransition(
    _ prepare: () throws -> ExternalTransition?
  ) throws {
    try ensureHydrated()
    guard !clearPending else { throw ClerkIdentityStoreError.clearPending }
    if isSharingIdentity {
      try reconcile()
    }
    guard let transition = try prepare() else { return }
    try commit(
      transition.identity, fenceResponses: transition.fenceAllClientResponses,
      watchClearGeneration: transition.watchClearGeneration, recordsClear: transition.recordsClear
    )
    transition.didApply()
  }

  func updateDeviceToken(to deviceToken: String) async throws -> DeviceTokenTransitionResult {
    try ensureHydrated()
    guard !clearPending else { throw ClerkIdentityStoreError.clearPending }
    if isSharingIdentity {
      try reconcile()
    }
    guard currentDeviceToken != deviceToken else { return .unchanged }
    try commit(
      ClerkIdentitySnapshot(state: .cleared, deviceToken: deviceToken, client: nil, serverDate: nil),
      fenceResponses: true
    )
    return .applied
  }

  /// Replaces the persisted identity with a credential-free clear record and signs this app out. With shared-session sync,
  /// this signs out every app sharing the identity.
  func clearIdentity() throws {
    guard let clerk else { return }
    clearPending = true
    fenceClientResponses()
    currentDeviceToken = nil
    lastServerDate = nil
    clerk.setClientFromIdentityController(nil)
    clerk.emitInternalStateChange(.localStorageDidClear)
    let cleared = try store?.clear()
    try observeWatchClear(cleared)
    storedRecord = cleared
    clearPending = false
    clerk.emitInternalStateChange(.localStorageDidClear)
    notifier?.post()
  }

  private struct WatchClearObservation: Codable {
    let epoch: UUID
    let generation: Int
  }

  private func observeWatchClear(_ record: ClerkIdentityStore.Record?) throws {
    guard let clerk, let store, let record else { return }
    do {
      let keychain = clerk.dependencies.watchSyncKeychain
      guard let epoch = record.clearEpoch ?? (record.identity.deviceToken == nil ? record.epoch : nil) else {
        if let generation = record.watchClearGeneration {
          try WatchSyncClearMarker.raise(to: generation, in: keychain)
        }
        return
      }
      let key = "\(store.clearIntentKey).watchClear"
      let previous = try clerk.dependencies.appLocalKeychain.data(forKey: key).map {
        try JSONDecoder.clerkDecoder.decode(WatchClearObservation.self, from: $0)
      }
      let localGeneration = try WatchSyncClearMarker.generation(in: keychain)
      var generation = max(localGeneration, record.watchClearGeneration ?? 0)
      if let previous, previous.epoch == epoch {
        guard previous.generation >= 0 else { throw KeychainError.invalidStringEncoding }
        generation = max(generation, previous.generation)
      } else {
        // A sibling's counter can trail this app's. An unseen clear must advance
        // beyond our old snapshots, even if the sibling already counted that clear.
        if record.watchClearEpoch != epoch || generation == localGeneration {
          let (next, overflow) = generation.addingReportingOverflow(1)
          guard !overflow else { throw KeychainError.invalidStringEncoding }
          generation = next
        }
        // Record the epoch and its chosen generation together before raising the
        // counter, so a failed write or restart retries without counting it again.
        try clerk.dependencies.appLocalKeychain.set(JSONEncoder.clerkEncoder.encode(WatchClearObservation(
          epoch: epoch, generation: generation
        )), forKey: key)
      }
      try WatchSyncClearMarker.raise(to: generation, in: keychain)
    } catch {
      // The shared clear may already be committed. Until the paired-device fence
      // is durable, do not expose credentials or accept a stale Watch transition.
      hydrationError = error
      clearPending = true
      currentDeviceToken = nil
      fenceClientResponses()
      clerk.setClientFromIdentityController(nil)
      throw error
    }
  }

  /// Persists the complete transition before applying it to memory. A conflict
  /// belongs to the caller: never silently rebase a prepared identity.
  private func commit(
    _ identity: ClerkIdentitySnapshot,
    fenceResponses: Bool = false,
    watchClearGeneration: Int? = nil,
    recordsClear: Bool = false,
    authFlowUpdate: AuthFlowIdentityUpdate = .ordinary
  ) throws {
    try ensureHydrated()
    let tokenChanged = identity.deviceToken != currentDeviceToken
    var identity = identity
    // Persist the same server-date watermark memory keeps, so the next launch hydrates it.
    if !tokenChanged, let watermark = lastServerDate, identity.serverDate.map({ $0 < watermark }) ?? true {
      identity = ClerkIdentitySnapshot(
        state: identity.state,
        deviceToken: identity.deviceToken,
        client: identity.client,
        serverDate: watermark
      )
    }
    guard !clearPending else { throw ClerkIdentityStoreError.clearPending }
    var epochChanged = false
    // A Client without a device token only exists in memory; it cannot be persisted.
    if let store, identity.deviceToken != nil || identity.client == nil {
      let record: ClerkIdentityStore.Record
      do {
        record = try store.save(
          identity, replacing: storedRecord, watchClearGeneration: watchClearGeneration, recordsClear: recordsClear
        )
      } catch ClerkIdentityStoreError.writeConflict {
        // Adopt the winner, but do not give this prepared transition a new revision.
        try reconcile()
        throw ClerkIdentityStoreError.writeConflict
      }
      try observeWatchClear(record)
      epochChanged = storedRecord?.epoch != record.epoch
      storedRecord = record
    }
    apply(identity, fenceResponses: fenceResponses || tokenChanged || epochChanged, authFlowUpdate: authFlowUpdate)
    notifier?.post()
  }

  private func apply(
    _ identity: ClerkIdentitySnapshot,
    fenceResponses: Bool,
    authFlowUpdate: AuthFlowIdentityUpdate = .ordinary
  ) {
    guard let clerk else { return }
    let tokenChanged = identity.deviceToken != currentDeviceToken
    currentDeviceToken = identity.deviceToken
    if fenceResponses {
      fenceClientResponses()
    }
    if tokenChanged || (identity.state == .cleared && identity.serverDate == nil) {
      lastServerDate = identity.serverDate
    } else {
      responseOrderingGate.advanceServerDateWatermark(to: identity.serverDate)
    }
    clerk.setClientFromIdentityController(identity.client, authFlowUpdate: authFlowUpdate)
    clerk.emitInternalStateChange(.identityDidChange)
  }
}

// MARK: - Network Responses

extension ClerkIdentityController {
  func applyNetworkResponse(_ context: ClientSyncResponseContext) async throws {
    guard let clerk else { throw CancellationError() }
    try ensureHydrated()
    guard !clearPending else { throw ClerkIdentityStoreError.clearPending }
    if isSharingIdentity { try reconcile() }
    guard responseCanBeAccepted(
      nil,
      responseSequence: context.responseSequence,
      serverDate: context.serverDate,
      clientResponseGeneration: context.clientResponseGeneration,
      checksOrdering: false
    ), let identity = try context.resolvedIdentityPayload(
      currentDeviceToken: currentDeviceToken,
      currentClient: clerk.client,
      currentServerDate: lastServerDate
    ), responseCanBeAccepted(
      identity.client,
      responseSequence: context.responseSequence,
      serverDate: context.serverDate,
      clientResponseGeneration: context.clientResponseGeneration,
      isExplicitClear: context.update == .explicitClear
    ) else {
      resolveRejectedResponseAuthFlow(context.completedAuthFlow, ownerId: context.authFlowRegistrationId)
      return
    }
    let epoch = storedRecord?.epoch
    do {
      try commit(identity, authFlowUpdate: authFlowUpdate(
        for: context.completedAuthFlow, ownerId: context.authFlowRegistrationId
      ))
    } catch ClerkIdentityStoreError.writeConflict {
      // The server operation already ran. Recover with a read, never by making
      // the caller repeat its mutation. A canonical read cannot recurse here.
      if !context.isCanonicalClientRequest, storedRecord?.epoch == epoch {
        let runtime = clerk.runtimeScope
        do {
          try await clerk.refreshClient(skipClientId: true)
        } catch {
          try Task.checkCancellation()
          try runtime.validateStableRuntime()
          ClerkLogger.logError(error, message: "Failed to refresh the Clerk client after a persistence conflict")
        }
        try runtime.validateStableRuntime()
      }
      resolveRejectedResponseAuthFlow(context.completedAuthFlow, ownerId: context.authFlowRegistrationId)
      return
    }
    responseOrderingGate.record(sequence: context.responseSequence)
    emitAcceptedAuthCompletion(context.completedAuthFlow, clerk: clerk)
  }

  /// Applies a Client decoded outside the response middleware, keeping the current device token.
  func applyResponseClient(
    _ incoming: Client?,
    responseSequence: Int? = nil,
    serverDate: Date? = nil,
    clientResponseGeneration: ClientResponseGeneration? = nil,
    completedAuthFlow: TransferFlowResult? = nil,
    completedAuthFlowOwnerId: UUID? = nil
  ) {
    do {
      try ensureHydrated()
      if isSharingIdentity { try reconcile() }
      guard responseCanBeAccepted(
        incoming,
        responseSequence: responseSequence,
        serverDate: serverDate,
        clientResponseGeneration: clientResponseGeneration
      ) else {
        resolveSupersededAuthFlowCompletion(completedAuthFlow, ownerId: completedAuthFlowOwnerId)
        return
      }

      let identity = ClerkIdentitySnapshot(
        state: incoming == nil ? .cleared : .present,
        deviceToken: currentDeviceToken,
        client: incoming,
        serverDate: serverDate
      )
      try commit(identity, authFlowUpdate: authFlowUpdate(for: completedAuthFlow, ownerId: completedAuthFlowOwnerId))
      responseOrderingGate.record(sequence: responseSequence)
    } catch ClerkIdentityStoreError.writeConflict {
      resolveSupersededAuthFlowCompletion(completedAuthFlow, ownerId: completedAuthFlowOwnerId)
    } catch {
      ClerkLogger.logError(error, message: "Failed to apply the Clerk client")
    }
  }

  private func responseCanBeAccepted(
    _ incoming: Client?,
    responseSequence: Int?,
    serverDate: Date?,
    clientResponseGeneration: ClientResponseGeneration?,
    checksOrdering: Bool = true,
    isExplicitClear: Bool = false
  ) -> Bool {
    if let clientResponseGeneration, clientResponseGeneration != self.clientResponseGeneration {
      ClerkLogger.debug(
        "Ignoring client response from stale device token generation. Current generation: \(self.clientResponseGeneration), incoming generation: \(clientResponseGeneration)"
      )
      return false
    }

    guard checksOrdering else { return true }
    guard responseOrderingGate.accepts(
      sequence: responseSequence,
      serverDate: serverDate,
      incomingUpdatedAt: incoming?.updatedAt,
      currentUpdatedAt: clerk?.client?.updatedAt,
      isExplicitClear: isExplicitClear
    ) else {
      ClerkLogger.debug(
        "Ignoring stale client response. Current sequence: \(String(describing: responseOrderingGate.lastAcceptedSequence)), incoming sequence: \(String(describing: responseSequence))"
      )
      return false
    }
    return true
  }
}
