//
//  ClerkIdentityController.swift
//  Clerk
//

// swiftlint:disable file_length

import Foundation

///
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
  private var hydrationFailed = false

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

  private var store: ClerkIdentityStore? {
    clerk?.dependencies.identityStore
  }
}

extension ClerkIdentityController {
  func prepareForConfiguration() {
    currentDeviceToken = nil
    hydrationFailed = false
  }

  func hydrate() {
    guard let clerk, let store else { return }
    let identity: ClerkIdentitySnapshot?
    do {
      identity = try store.load()
    } catch {
      ClerkLogger.logError(error, message: "Failed to load the persisted Clerk identity")
      hydrationFailed = true
      return
    }
    hydrationFailed = false
    guard let identity else { return }
    currentDeviceToken = identity.deviceToken
    guard clerk.client == nil else { return }
    lastServerDate = identity.serverDate
    if identity.client != nil {
      clerk.setClientFromIdentityController(identity.client)
    }
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
    hydrationFailed = false
    lastServerDate = nil
    clerk.setClientFromIdentityController(nil)
  }

  func fenceClientResponses() {
    clientResponseGeneration = clientResponseGeneration.next()
    responseOrderingGate.resetSequence()
  }

  func persistedClientID() -> String? {
    try? store?.load()?.client?.id
  }
}

extension ClerkIdentityController {
  @discardableResult
  func adoptStoredDeviceToken() -> Bool {
    // Another app changes the token only through a shared access group.
    guard let store, clerk?.dependencies.identityIsInAccessGroup == true || hydrationFailed else { return false }
    let identity: ClerkIdentitySnapshot?
    do {
      let storedToken = try store.deviceToken()
      hydrationFailed = false
      guard storedToken != currentDeviceToken else { return false }
      identity = try store.load()
    } catch {
      ClerkLogger.logError(error, message: "Failed to read the stored Clerk identity")
      return false
    }
    apply(identity ?? .signedOut, fenceResponses: true, authFlowUpdate: .authoritativeIdentityChanged)
    return true
  }

  func captureRequestIdentity(
    startupClientRefreshTakeoverID: UUID? = nil
  ) async throws -> ClerkIdentityRequestSnapshot {
    guard let clerk else { throw CancellationError() }
    adoptStoredDeviceToken()
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
}

extension ClerkIdentityController {
  func applyExternalTransition(
    _ prepare: () throws -> ExternalTransition?
  ) throws {
    adoptStoredDeviceToken()
    guard let transition = try prepare() else { return }
    try commit(transition.identity, fenceResponses: transition.fenceAllClientResponses)
    transition.didApply()
  }

  func updateDeviceToken(to deviceToken: String) async throws -> DeviceTokenTransitionResult {
    adoptStoredDeviceToken()
    guard currentDeviceToken != deviceToken else { return .unchanged }
    try commit(
      ClerkIdentitySnapshot(state: .cleared, deviceToken: deviceToken, client: nil, serverDate: nil),
      fenceResponses: true
    )
    return .applied
  }

  func clearIdentity() throws {
    guard let clerk else { return }
    fenceClientResponses()
    currentDeviceToken = nil
    lastServerDate = nil
    clerk.setClientFromIdentityController(nil)
    clerk.emitInternalStateChange(.localStorageDidClear)
    try store?.delete()
  }

  private func commit(
    _ identity: ClerkIdentitySnapshot,
    fenceResponses: Bool = false,
    authFlowUpdate: AuthFlowIdentityUpdate = .ordinary
  ) throws {
    let tokenChanged = identity.deviceToken != currentDeviceToken
    var identity = identity
    if !tokenChanged, let watermark = lastServerDate, identity.serverDate.map({ $0 < watermark }) ?? true {
      identity = ClerkIdentitySnapshot(
        state: identity.state,
        deviceToken: identity.deviceToken,
        client: identity.client,
        serverDate: watermark
      )
    }
    if let store, identity.deviceToken != nil || identity.client == nil {
      if tokenChanged {
        try store.saveDeviceToken(identity.deviceToken)
      }
      do {
        try store.saveClient(identity.client, serverDate: identity.serverDate, for: identity.deviceToken)
      } catch {
        ClerkLogger.logError(error, message: "Failed to cache the Clerk client")
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

extension ClerkIdentityController {
  func applyNetworkResponse(_ context: ClientSyncResponseContext) async throws {
    guard let clerk else { throw CancellationError() }
    adoptStoredDeviceToken()

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
