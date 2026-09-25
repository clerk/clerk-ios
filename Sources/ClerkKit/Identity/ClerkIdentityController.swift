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
    var didApply: @MainActor () -> Void = {}
  }

  weak var clerk: Clerk?

  private(set) var currentDeviceToken: String?
  private var storedRevision: UUID?
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

  private var store: ClerkIdentityStore? {
    clerk?.dependencies.identityStore
  }
}

// MARK: - Lifecycle

extension ClerkIdentityController {
  func prepareForConfiguration() {
    stopSharing()
    currentDeviceToken = nil
    storedRevision = nil
  }

  /// Loads the persisted identity during configuration without emitting changes.
  func hydrate() {
    guard let clerk, let store else { return }
    let record: ClerkIdentityStore.Record?
    do {
      record = try store.load()
    } catch ClerkIdentityStoreError.otherInstance {
      return
    } catch {
      ClerkLogger.logError(error, message: "Failed to load the persisted Clerk identity")
      return
    }
    storedRevision = record?.revision
    guard let identity = record?.identity else { return }
    currentDeviceToken = identity.deviceToken
    guard clerk.client == nil else { return }
    lastServerDate = identity.serverDate
    if identity.client != nil {
      clerk.setClientFromIdentityController(identity.client)
    }
  }

  /// Shares the identity with other apps in the access group.
  func startSharing(notifier: any SharedSessionSyncNotifying) {
    self.notifier = notifier
    notifier.setHandler { [weak self] in
      _ = self?.reconcileWithStore()
    }
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
  }

  func resetOrderingState() {
    responseOrderingGate.reset()
  }

  func resetRuntimeIdentity() {
    guard let clerk else { return }
    currentDeviceToken = nil
    storedRevision = nil
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
    guard let store else { return false }
    let record: ClerkIdentityStore.Record?
    do {
      let revision = try store.revision()
      guard revision != storedRevision else { return false }
      do {
        record = try store.load()
      } catch ClerkIdentityStoreError.otherInstance {
        // Another app sharing the group uses a different Clerk instance; leave this app's identity alone.
        storedRevision = revision
        return false
      }
    } catch {
      ClerkLogger.logError(error, message: "Failed to read the shared Clerk identity")
      return false
    }
    storedRevision = record?.revision

    let identity = record?.identity ?? .signedOut
    let tokenChanged = identity.deviceToken != currentDeviceToken
    apply(identity, fenceResponses: tokenChanged, authFlowUpdate: .authoritativeIdentityChanged)
    if !tokenChanged {
      responseOrderingGate.adoptExternalSnapshot(serverDate: identity.serverDate)
    }
    return true
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
    if isSharingIdentity {
      reconcileWithStore()
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
    if isSharingIdentity {
      reconcileWithStore()
    }
    guard let transition = try prepare() else { return }
    try commit(transition.identity, fenceResponses: transition.fenceAllClientResponses)
    transition.didApply()
  }

  func updateDeviceToken(to deviceToken: String) async throws -> DeviceTokenTransitionResult {
    if isSharingIdentity {
      reconcileWithStore()
    }
    guard currentDeviceToken != deviceToken else { return .unchanged }
    try commit(
      ClerkIdentitySnapshot(state: .cleared, deviceToken: deviceToken, client: nil, serverDate: nil),
      fenceResponses: true
    )
    return .applied
  }

  /// Removes the persisted identity and signs this app out. With shared-session sync,
  /// this signs out every app sharing the identity.
  func clearIdentity() throws {
    guard let clerk else { return }
    fenceClientResponses()
    currentDeviceToken = nil
    lastServerDate = nil
    clerk.setClientFromIdentityController(nil)
    clerk.emitInternalStateChange(.localStorageDidClear)
    do {
      try store?.delete()
    } catch {
      // Remember the record this clear could not delete, so reconciling does not mistake it
      // for another app's write and sign the user back in.
      storedRevision = try? store?.revision()
      throw error
    }
    storedRevision = nil
    notifier?.post()
  }

  /// Persists `identity`, then applies it to memory.
  ///
  /// A write that would change the device token must succeed, because losing a new
  /// token would sign the user out on the next launch. Other write failures are
  /// logged and the identity is still applied, since the next response rewrites it.
  private func commit(
    _ identity: ClerkIdentitySnapshot,
    fenceResponses: Bool = false,
    authFlowUpdate: AuthFlowIdentityUpdate = .ordinary
  ) throws {
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
    // A Client without a device token only exists in memory; it cannot be persisted.
    if let store, identity.deviceToken != nil || identity.client == nil {
      do {
        storedRevision = try store.save(identity)?.revision
        notifier?.post()
      } catch {
        guard !tokenChanged else { throw error }
        ClerkLogger.logError(error, message: "Failed to persist the Clerk identity")
      }
    }
    apply(identity, fenceResponses: fenceResponses || tokenChanged, authFlowUpdate: authFlowUpdate)
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
    if isSharingIdentity {
      reconcileWithStore()
    }

    guard let identity = try context.resolvedIdentityPayload(
      currentDeviceToken: currentDeviceToken,
      currentClient: clerk.client,
      currentServerDate: lastServerDate
    ), responseCanBeAccepted(
      identity.client,
      responseSequence: context.responseSequence,
      serverDate: context.serverDate,
      clientResponseGeneration: context.clientResponseGeneration
    ) else {
      resolveRejectedResponseAuthFlow(context.completedAuthFlow, ownerId: context.authFlowRegistrationId)
      return
    }

    try commit(identity, authFlowUpdate: authFlowUpdate(
      for: context.completedAuthFlow,
      ownerId: context.authFlowRegistrationId
    ))
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
    guard responseCanBeAccepted(
      incoming,
      responseSequence: responseSequence,
      serverDate: serverDate,
      clientResponseGeneration: clientResponseGeneration
    ) else {
      resolveSupersededAuthFlowCompletion(completedAuthFlow, ownerId: completedAuthFlowOwnerId)
      return
    }

    responseOrderingGate.advanceServerDateWatermark(to: serverDate)
    let identity = ClerkIdentitySnapshot(
      state: incoming == nil ? .cleared : .present,
      deviceToken: currentDeviceToken,
      client: incoming,
      serverDate: lastServerDate
    )
    do {
      try commit(identity, authFlowUpdate: authFlowUpdate(for: completedAuthFlow, ownerId: completedAuthFlowOwnerId))
    } catch {
      ClerkLogger.logError(error, message: "Failed to apply the Clerk client")
    }
    responseOrderingGate.record(sequence: responseSequence)
  }

  private func responseCanBeAccepted(
    _ incoming: Client?,
    responseSequence: Int?,
    serverDate: Date?,
    clientResponseGeneration: ClientResponseGeneration?
  ) -> Bool {
    if let clientResponseGeneration, clientResponseGeneration != self.clientResponseGeneration {
      ClerkLogger.debug(
        "Ignoring client response from stale device token generation. Current generation: \(self.clientResponseGeneration), incoming generation: \(clientResponseGeneration)"
      )
      return false
    }

    guard responseOrderingGate.accepts(
      sequence: responseSequence,
      serverDate: serverDate,
      incomingUpdatedAt: incoming?.updatedAt,
      currentUpdatedAt: clerk?.client?.updatedAt
    ) else {
      ClerkLogger.debug(
        "Ignoring stale client response. Current sequence: \(String(describing: responseOrderingGate.lastAcceptedSequence)), incoming sequence: \(String(describing: responseSequence))"
      )
      return false
    }
    return true
  }
}
