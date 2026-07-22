//
//  ClerkIdentityController.swift
//  Clerk
//

import Foundation

/// Owns Clerk's complete in-memory identity and selects its persistence mode.
///
/// Identity producers submit complete transitions here. Shared-session transport
/// remains responsible for owner slots, generations, reduction, and peer
/// reconciliation; this controller owns the boundary between that transport,
/// app-local atomic persistence, legacy persistence, and `Clerk` memory.
@MainActor
final class ClerkIdentityController {
  private struct PersistedClientSnapshot {
    let state: String?
    let client: Client?
    let serverDate: Date?
  }

  private enum PersistedClientDecision {
    case apply
    case ignore
  }

  struct RollbackState {
    let lastAppliedResponseSequence: Int?
    let lastServerDate: Date?
  }

  struct ExternalTransition {
    let identity: ClerkIdentitySnapshot
    let fenceAllClientResponses: Bool
    let stage: @MainActor () throws -> Void
    let didApply: @MainActor () -> Void
    let didNotApply: @MainActor () -> Void

    init(
      identity: ClerkIdentitySnapshot,
      fenceAllClientResponses: Bool = true,
      stage: @escaping @MainActor () throws -> Void = {},
      didApply: @escaping @MainActor () -> Void = {},
      didNotApply: @escaping @MainActor () -> Void = {}
    ) {
      self.identity = identity
      self.fenceAllClientResponses = fenceAllClientResponses
      self.stage = stage
      self.didApply = didApply
      self.didNotApply = didNotApply
    }
  }

  struct StorageClearContext {
    let usesAtomicLocalPersistence: Bool
    let invalidatedThroughRevision: UInt64
    let requiresOwnerSlotWithdrawal: Bool
    fileprivate let sharedCoordinator: SharedSessionSyncCoordinator?
  }

  private enum PersistenceMode {
    case shared(SharedSessionSyncCoordinator)
    case atomicLocal(SharedSessionLocalIdentityIO)
    case legacy
  }

  weak var clerk: Clerk?

  var localDeviceToken: String?
  var localOperationRevision: UInt64 = 0
  var invalidatedThroughRevision: UInt64 = 0
  private var localOperationTail: Task<Void, Never>?

  private(set) var clientResponseGeneration: ClientResponseGeneration = .initial
  private var responseOrderingGate = ClientResponseOrderingGate()
  var lastServerDate: Date? {
    get { responseOrderingGate.lastAcceptedServerDate }
    set { responseOrderingGate.lastAcceptedServerDate = newValue }
  }

  private(set) var isApplyingIdentityTransition = false
  private(set) var isClientProvisional = false

  init(clerk: Clerk) {
    self.clerk = clerk
  }

  var usesAtomicLocalPersistence: Bool {
    clerk?.dependencies.atomicIdentityStore != nil
  }

  var authoritativeClient: Client? {
    guard !isClientProvisional else { return nil }
    return clerk?.client
  }

  var currentDeviceToken: String? {
    guard let clerk else { return nil }
    let deviceToken: String?
    switch persistenceMode(for: clerk) {
    case .shared(let coordinator):
      deviceToken = coordinator.currentDeviceToken
    case .atomicLocal:
      deviceToken = localDeviceToken
    case .legacy:
      do {
        deviceToken = try clerk.dependencies.identityKeychain.string(
          forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
        )
      } catch {
        ClerkLogger.logError(error, message: "Failed to read device token from keychain")
        return nil
      }
    }
    return deviceToken.nilIfEmpty
  }

  func validateClientMutation() {
    guard usesAtomicLocalPersistence,
          !isApplyingIdentityTransition,
          !EnvironmentDetection.isRunningInTests
    else {
      return
    }
    assertionFailure(
      "Complete Clerk identity changes must be submitted through ClerkIdentityController."
    )
  }
}

// MARK: - Runtime Lifecycle and Local Operations

extension ClerkIdentityController {
  func prepareForConfiguration() {
    localOperationRevision &+= 1
    localDeviceToken = nil
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

  func enqueueLocalOperation<T: Sendable>(
    _ operation: @escaping @MainActor @Sendable (_ operationRevision: UInt64) async throws -> T
  ) -> Task<T, Error> {
    localOperationRevision &+= 1
    let operationRevision = localOperationRevision
    let predecessor = localOperationTail
    let task = Task { @MainActor [weak self] in
      _ = await predecessor?.value
      try Task.checkCancellation()
      guard let self,
            operationRevision > invalidatedThroughRevision
      else {
        throw CancellationError()
      }
      return try await operation(operationRevision)
    }
    localOperationTail = Task { @MainActor in
      _ = await task.result
    }
    return task
  }

  func waitForPendingLocalOperations() async {
    await localOperationTail?.value
  }

  @discardableResult
  func invalidateLocalOperations() -> UInt64 {
    localOperationRevision &+= 1
    invalidatedThroughRevision = localOperationRevision
    return localOperationRevision
  }

  func invalidateAndDrainLocalOperations(
    through localIdentityIO: SharedSessionLocalIdentityIO?
  ) async {
    let revision = invalidateLocalOperations()
    do {
      try await localIdentityIO?.invalidateOperations(through: revision)
    } catch {
      ClerkLogger.logError(error, message: "Failed to invalidate Clerk's local identity operations")
    }
    await localOperationTail?.value
    localOperationTail = nil
  }
}

// MARK: - Request and Response Routing

extension ClerkIdentityController {
  func applyNetworkResponse(_ context: ClientSyncResponseContext) async throws {
    guard let clerk else { throw CancellationError() }
    switch persistenceMode(for: clerk) {
    case .shared(let coordinator):
      guard context.baseGeneration != nil else { return }
      try await coordinator.handleNetworkResponse(context)
    case .atomicLocal(let localIdentityIO):
      _ = try await applyAtomicLocalResponse(
        context,
        localIdentityIO: localIdentityIO,
        clerk: clerk
      )
    case .legacy:
      try applyLegacyResponse(context, clerk: clerk)
    }
  }

  func applyLegacyResponseClient(
    _ incoming: Client?,
    responseSequence: Int? = nil,
    serverDate: Date? = nil,
    clientResponseGeneration: ClientResponseGeneration? = nil
  ) {
    guard let clerk,
          case .legacy = persistenceMode(for: clerk),
          responseCanBeAccepted(
            incoming,
            responseSequence: responseSequence,
            serverDate: serverDate,
            clientResponseGeneration: clientResponseGeneration,
            clerk: clerk
          )
    else {
      return
    }

    recordAcceptedServerDate(serverDate)
    setClient(incoming, on: clerk)
    responseOrderingGate.record(sequence: responseSequence)
  }

  func applyDecodedClientFallback(
    _ client: Client,
    responseSequence: Int?,
    serverDate: Date?,
    clientResponseGeneration: ClientResponseGeneration
  ) {
    guard let clerk else { return }
    guard case .legacy = persistenceMode(for: clerk) else { return }
    applyLegacyResponseClient(
      client,
      responseSequence: responseSequence,
      serverDate: serverDate,
      clientResponseGeneration: clientResponseGeneration
    )
  }
}

// MARK: - Identity Transitions

extension ClerkIdentityController {
  /// Enqueues a complete external identity transition on the active persistence
  /// boundary. The preparation closure runs only after earlier identity work and
  /// may reject the transition by returning `nil`.
  func submitExternalTransition(
    prepare: @escaping @MainActor @Sendable () throws -> ExternalTransition?
  ) throws -> Task<Void, Error>? {
    guard let clerk else { throw CancellationError() }
    switch persistenceMode(for: clerk) {
    case .shared(let coordinator):
      return coordinator.enqueueSerializedLocalIdentityOperation { [weak self, weak clerk] in
        guard let self,
              let clerk,
              case .shared(let currentCoordinator) = persistenceMode(for: clerk),
              currentCoordinator === coordinator,
              let transition = try prepare()
        else {
          return
        }
        do {
          try transition.stage()
          let identity = try transition.identity.validated()
          let didApply = try await coordinator.publishReservedLocalIdentity(
            state: identity.state,
            deviceToken: identity.deviceToken,
            client: identity.client,
            serverDate: identity.serverDate
          )
          if didApply {
            transition.didApply()
          } else {
            transition.didNotApply()
          }
        } catch {
          transition.didNotApply()
          throw error
        }
      }
    case .atomicLocal(let localIdentityIO):
      return enqueueLocalOperation { [weak self, weak clerk] operationRevision in
        guard let self,
              let clerk,
              clerk.sharedSessionSyncCoordinator == nil,
              clerk.dependencies.atomicIdentityIO === localIdentityIO,
              let transition = try prepare()
        else {
          return
        }
        do {
          try transition.stage()
          guard try await persistAndApplyAtomicIdentity(
            transition.identity,
            through: localIdentityIO,
            operationRevision: operationRevision,
            fenceAllClientResponses: transition.fenceAllClientResponses
          ) else {
            transition.didNotApply()
            return
          }
          transition.didApply()
        } catch {
          transition.didNotApply()
          throw error
        }
      }
    case .legacy:
      guard let transition = try prepare() else { return nil }
      do {
        try transition.stage()
        try persistLegacyIdentity(transition.identity, clerk: clerk)
        applyIdentityToMemory(
          transition.identity,
          clerk: clerk,
          fenceAllClientResponses: transition.fenceAllClientResponses,
          emitIdentityChange: false
        )
        transition.didApply()
      } catch {
        transition.didNotApply()
        throw error
      }
      return nil
    }
  }

  func updateDeviceToken(to deviceToken: String) async throws -> DeviceTokenTransitionResult {
    guard let clerk else { throw CancellationError() }

    switch persistenceMode(for: clerk) {
    case .shared(let coordinator):
      let task = coordinator.enqueueSerializedLocalIdentityOperation { [weak self, weak clerk] in
        guard let self,
              let clerk,
              case .shared(let currentCoordinator) = persistenceMode(for: clerk),
              currentCoordinator === coordinator
        else {
          throw CancellationError()
        }
        guard coordinator.currentDeviceToken != deviceToken else {
          return DeviceTokenTransitionResult.unchanged
        }
        let identity = try clearedIdentity(with: deviceToken)
        let didApply = try await coordinator.publishReservedLocalIdentity(
          state: identity.state,
          deviceToken: identity.deviceToken,
          client: identity.client,
          serverDate: identity.serverDate
        )
        if didApply {
          return DeviceTokenTransitionResult.applied
        }
        return coordinator.currentDeviceToken == deviceToken ? .unchanged : .rejected
      }
      return try await task.value
    case .atomicLocal(let localIdentityIO):
      let task = enqueueLocalOperation { [weak self] operationRevision in
        guard let self else { throw CancellationError() }
        guard localDeviceToken != deviceToken else {
          return DeviceTokenTransitionResult.unchanged
        }
        let identity = try clearedIdentity(with: deviceToken)
        let didApply = try await persistAndApplyAtomicIdentity(
          identity,
          through: localIdentityIO,
          operationRevision: operationRevision,
          fenceAllClientResponses: false
        )
        return didApply ? DeviceTokenTransitionResult.applied : DeviceTokenTransitionResult.rejected
      }
      return try await task.value
    case .legacy:
      guard currentDeviceToken != deviceToken else { return .unchanged }
      let identity = try clearedIdentity(with: deviceToken)
      try persistLegacyIdentity(identity, clerk: clerk)
      applyIdentityToMemory(
        identity,
        clerk: clerk,
        fenceAllClientResponses: true,
        emitIdentityChange: true
      )
      for key in [ClerkKeychainKey.cachedClient, .cachedClientServerDate] {
        do {
          try clerk.dependencies.identityKeychain.deleteItem(forKey: key.rawValue)
        } catch {
          ClerkLogger.logError(error, message: "Failed to clear cached Clerk data after device token update")
        }
      }
      return .applied
    }
  }

  private func clearedIdentity(with deviceToken: String) throws -> ClerkIdentitySnapshot {
    try ClerkIdentitySnapshot(
      state: .cleared,
      deviceToken: deviceToken,
      client: nil,
      serverDate: nil
    ).validated()
  }

  func applySharedEvent(
    _ event: SharedSessionIdentityEvent,
    previousDeviceToken: String?
  ) {
    guard let clerk else { return }
    localDeviceToken = event.deviceToken
    if previousDeviceToken != event.deviceToken {
      fenceClientResponses()
    }
    applyIdentityToMemory(
      ClerkIdentitySnapshot(
        state: event.state,
        deviceToken: event.deviceToken,
        client: event.client,
        serverDate: event.serverDate
      ),
      clerk: clerk,
      fenceAllClientResponses: false,
      emitIdentityChange: true,
      fenceTokenChange: false
    )
  }
}

// MARK: - Hydration and Atomic Persistence

extension ClerkIdentityController {
  func hydrateAtomicIdentityIfNeeded(_ identity: ClerkIdentitySnapshot) {
    guard let clerk else { return }
    localDeviceToken = identity.deviceToken
    guard clerk.client == nil else { return }
    lastServerDate = identity.serverDate
    if identity.client != nil {
      setClient(identity.client, on: clerk)
    }
  }

  func hydrateLegacyClientIfNeeded(_ client: Client?, serverDate: Date?) {
    guard let clerk, clerk.client == nil else { return }
    if let serverDate {
      lastServerDate = serverDate
    }
    setClient(client, on: clerk)
  }

  func hydrateProvisionalLegacyClientIfNeeded(_ client: Client?) {
    guard let clerk, clerk.client == nil, let client else { return }
    isClientProvisional = true
    withApplyingIdentityTransition {
      clerk.setClientFromIdentityController(client)
    }
  }

  func hydrateLegacyServerDateIfNeeded(_ date: Date) {
    guard let clerk, clerk.client == nil, lastServerDate == nil else { return }
    lastServerDate = date
  }

  func persistedClientID() async -> String? {
    guard let clerk else { return nil }
    if let localIdentityIO = clerk.dependencies.atomicIdentityIO {
      return try? await localIdentityIO.loadRecord()?.acceptedIdentity?.client?.id
    }
    guard let clientData = try? clerk.dependencies.identityKeychain.data(
      forKey: ClerkKeychainKey.cachedClient.rawValue
    ) else {
      return nil
    }
    return try? JSONDecoder.clerkDecoder.decode(Client.self, from: clientData).id
  }

  @discardableResult
  func persistAndApplyAtomicIdentity(
    _ identity: ClerkIdentitySnapshot,
    through localIdentityIO: SharedSessionLocalIdentityIO,
    operationRevision: UInt64,
    fenceAllClientResponses: Bool
  ) async throws -> Bool {
    guard let clerk else { return false }
    let identity = try identity.validated()
    guard operationRevision > invalidatedThroughRevision else { return false }
    guard try await localIdentityIO.saveAcceptedIdentity(
      identity,
      operationRevision: operationRevision
    ) else {
      return false
    }
    guard operationRevision > invalidatedThroughRevision,
          clerk.dependencies.atomicIdentityIO === localIdentityIO
    else {
      return false
    }

    let previousToken = currentDeviceToken
    localDeviceToken = identity.deviceToken
    applyIdentityToMemory(
      identity,
      clerk: clerk,
      fenceAllClientResponses: fenceAllClientResponses || previousToken != identity.deviceToken,
      emitIdentityChange: true,
      fenceTokenChange: false
    )
    return true
  }

  func fenceClientResponses() {
    clientResponseGeneration = clientResponseGeneration.next()
    responseOrderingGate.resetSequence()
  }

  func clearCachedClientStateAfterDeviceTokenChange() {
    guard let clerk else { return }
    fenceClientResponses()
    lastServerDate = nil
    setClient(nil, on: clerk)

    if let localIdentityIO = clerk.dependencies.atomicIdentityIO {
      let task = enqueueLocalOperation { operationRevision in
        _ = try await localIdentityIO.delete(operationRevision: operationRevision)
      }
      Task { @MainActor in
        do {
          try await task.value
        } catch {
          ClerkLogger.logError(error, message: "Failed to clear cached Clerk identity after device token update")
        }
      }
      localDeviceToken = nil
      return
    }

    for key in [ClerkKeychainKey.cachedClient, .cachedClientServerDate] {
      do {
        try clerk.dependencies.identityKeychain.deleteItem(forKey: key.rawValue)
      } catch {
        ClerkLogger.logError(error, message: "Failed to clear cached Clerk data after device token update")
      }
    }
  }
}

// MARK: - Storage Clearing and Reloading

extension ClerkIdentityController {
  func clearAtomicIdentityFromMemory() {
    guard let clerk else { return }
    localDeviceToken = nil
    fenceClientResponses()
    applyIdentityToMemory(
      ClerkIdentitySnapshot(
        state: .cleared,
        deviceToken: nil,
        client: nil,
        serverDate: nil
      ),
      clerk: clerk,
      fenceAllClientResponses: false,
      emitIdentityChange: false,
      fenceTokenChange: false
    )
    clerk.emitInternalStateChange(.localStorageDidClear)
  }

  func beginStorageClear() -> StorageClearContext {
    guard let clerk else {
      return StorageClearContext(
        usesAtomicLocalPersistence: false,
        invalidatedThroughRevision: localOperationRevision,
        requiresOwnerSlotWithdrawal: false,
        sharedCoordinator: nil
      )
    }
    let usesAtomicLocalPersistence = usesAtomicLocalPersistence
    let invalidatedThroughRevision = invalidateLocalOperations()
    localDeviceToken = nil
    let sharedCoordinator = clerk.sharedSessionSyncCoordinator
    sharedCoordinator?.beginLocalClear()
    return StorageClearContext(
      usesAtomicLocalPersistence: usesAtomicLocalPersistence,
      invalidatedThroughRevision: invalidatedThroughRevision,
      requiresOwnerSlotWithdrawal: sharedCoordinator != nil,
      sharedCoordinator: sharedCoordinator
    )
  }

  func applyStorageClearToMemory(_ context: StorageClearContext) {
    if context.usesAtomicLocalPersistence {
      clearAtomicIdentityFromMemory()
    } else {
      fenceClientResponses()
    }
  }

  func deleteCapturedOwnerSlotAfterStorageClear(
    _ context: StorageClearContext
  ) async throws -> Bool {
    guard let sharedCoordinator = context.sharedCoordinator else { return true }
    try await sharedCoordinator.deleteOwnSlotDuringLocalClear()
    return true
  }

  func finishStorageClear(
    _ context: StorageClearContext,
    canReleaseSharedClearBarrier: Bool
  ) {
    if canReleaseSharedClearBarrier {
      context.sharedCoordinator?.endLocalClear()
    }
  }

  func resetRuntimeIdentity() {
    guard let clerk else { return }
    localDeviceToken = nil
    lastServerDate = nil
    isClientProvisional = false
    withApplyingIdentityTransition {
      clerk.setClientFromIdentityController(nil)
    }
  }

  func reloadPersistedState() async -> Bool {
    guard let clerk else { return false }

    let identityChanged: Bool
    switch persistenceMode(for: clerk) {
    case .shared(let coordinator):
      identityChanged = await coordinator.reloadFromSharedStorage()
    case .atomicLocal(let localIdentityIO):
      do {
        let task = enqueueLocalOperation { [weak self, weak clerk] _ in
          guard let self,
                let clerk,
                clerk.dependencies.atomicIdentityIO === localIdentityIO,
                let identity = try await localIdentityIO.loadRecord()?.acceptedIdentity
          else {
            return false
          }
          let currentIdentity = ClerkIdentitySnapshot(
            state: clerk.client == nil ? .cleared : .present,
            deviceToken: localDeviceToken,
            client: clerk.client,
            serverDate: lastServerDate
          )
          guard currentIdentity != identity else { return false }
          localDeviceToken = identity.deviceToken
          applyIdentityToMemory(
            identity,
            clerk: clerk,
            fenceAllClientResponses: true,
            emitIdentityChange: true,
            fenceTokenChange: false
          )
          return true
        }
        identityChanged = try await task.value
      } catch {
        ClerkLogger.logError(error, message: "Failed to reload Clerk's atomic identity")
        identityChanged = false
      }
    case .legacy:
      identityChanged = reloadLegacyClient(in: clerk)
    }

    return reloadPersistedEnvironment(in: clerk) || identityChanged
  }
}

// MARK: - Persistence Implementations

extension ClerkIdentityController {
  private func persistenceMode(for clerk: Clerk) -> PersistenceMode {
    if let coordinator = clerk.sharedSessionSyncCoordinator {
      return .shared(coordinator)
    }
    if let localIdentityIO = clerk.dependencies.atomicIdentityIO {
      return .atomicLocal(localIdentityIO)
    }
    return .legacy
  }

  private func reloadLegacyClient(in clerk: Clerk) -> Bool {
    do {
      let snapshot = try loadPersistedClientSnapshot(from: clerk.dependencies.keychain)
      if snapshot.state == "cleared"
        || (snapshot.client == nil && snapshot.serverDate != nil)
      {
        return applyPersistedClientClear(snapshot.serverDate, to: clerk)
      }
      guard let incomingClient = snapshot.client,
            persistedClientDecision(
              incomingClient,
              serverDate: snapshot.serverDate,
              currentClient: clerk.client
            ) == .apply
      else {
        return false
      }

      let previousDate = lastServerDate
      recordAcceptedServerDate(snapshot.serverDate)
      if incomingClient != clerk.client {
        setClient(incomingClient, on: clerk)
        return true
      }
      if previousDate != lastServerDate, let lastServerDate {
        clerk.cacheManager?.saveServerFetchDate(lastServerDate)
        return true
      }
      return false
    } catch {
      ClerkLogger.logError(error, message: "Failed to reload shared Clerk client state")
      return false
    }
  }

  private func loadPersistedClientSnapshot(
    from keychain: any KeychainStorage
  ) throws -> PersistedClientSnapshot {
    let state = try keychain.string(
      forKey: ClerkKeychainKey.sharedSessionSyncAuthState.rawValue
    )
    let serverDate = try keychain.string(
      forKey: ClerkKeychainKey.cachedClientServerDate.rawValue
    ).flatMap(TimeInterval.init).map(Date.init(timeIntervalSince1970:))
    let client = try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue).map {
      try JSONDecoder.clerkDecoder.decode(Client.self, from: $0)
    }
    return PersistedClientSnapshot(
      state: state,
      client: client,
      serverDate: serverDate
    )
  }

  private func persistedClientDecision(
    _ incomingClient: Client,
    serverDate: Date?,
    currentClient: Client?
  ) -> PersistedClientDecision {
    if let serverDate, let lastServerDate {
      if serverDate > lastServerDate { return .apply }
      if serverDate < lastServerDate { return .ignore }
      guard let currentClient else { return .ignore }
      return incomingClient.updatedAt > currentClient.updatedAt ? .apply : .ignore
    }
    guard let currentClient else {
      return lastServerDate == nil || serverDate != nil ? .apply : .ignore
    }
    if serverDate != nil { return .apply }
    guard lastServerDate == nil else { return .ignore }
    return incomingClient.updatedAt > currentClient.updatedAt ? .apply : .ignore
  }

  private func applyPersistedClientClear(_ serverDate: Date?, to clerk: Clerk) -> Bool {
    if let serverDate, let lastServerDate {
      guard serverDate > lastServerDate
        || (serverDate == lastServerDate && clerk.client != nil)
      else {
        return false
      }
    }
    let previousClient = clerk.client
    let previousDate = lastServerDate
    lastServerDate = serverDate
    if clerk.client != nil {
      setClient(nil, on: clerk)
    } else if previousDate != serverDate {
      clerk.cacheManager?.deleteClient(serverFetchDate: serverDate)
    }
    return previousClient != nil || previousDate != serverDate
  }

  private func reloadPersistedEnvironment(in clerk: Clerk) -> Bool {
    let keychain: any KeychainStorage = if usesAtomicLocalPersistence {
      clerk.dependencies.appLocalKeychain
    } else {
      clerk.dependencies.keychain
    }
    do {
      guard let data = try keychain.data(
        forKey: ClerkKeychainKey.cachedEnvironment.rawValue
      ) else {
        return false
      }
      let environment = try JSONDecoder.clerkDecoder.decode(
        Clerk.Environment.self,
        from: data
      )
      guard environment != clerk.environment else { return false }
      clerk.environment = environment
      return true
    } catch {
      ClerkLogger.logError(error, message: "Failed to reload shared Clerk environment state")
      return false
    }
  }

  private func applyAtomicLocalResponse(
    _ context: ClientSyncResponseContext,
    localIdentityIO: SharedSessionLocalIdentityIO,
    clerk: Clerk
  ) async throws -> Bool {
    let task = enqueueLocalOperation { [weak self] operationRevision in
      guard let self else { throw CancellationError() }
      guard clerk.sharedSessionSyncCoordinator == nil,
            clerk.dependencies.atomicIdentityIO === localIdentityIO
      else {
        throw CancellationError()
      }
      if let generation = context.clientResponseGeneration,
         generation != clientResponseGeneration
      {
        return false
      }
      guard let identity = try context.resolvedIdentityPayload(
        currentDeviceToken: currentDeviceToken,
        currentClient: clerk.authoritativeClient,
        currentServerDate: lastServerDate
      ) else {
        return false
      }
      guard responseCanBeAccepted(
        identity.client,
        responseSequence: context.responseSequence,
        serverDate: context.serverDate,
        clientResponseGeneration: context.clientResponseGeneration,
        clerk: clerk
      ) else {
        return false
      }
      let didApply = try await persistAndApplyAtomicIdentity(
        identity,
        through: localIdentityIO,
        operationRevision: operationRevision,
        fenceAllClientResponses: false
      )
      if didApply {
        responseOrderingGate.record(sequence: context.responseSequence)
      }
      return didApply
    }
    return try await task.value
  }

  private func applyLegacyResponse(
    _ context: ClientSyncResponseContext,
    clerk: Clerk
  ) throws {
    guard let identity = try context.resolvedIdentityPayload(
      currentDeviceToken: currentDeviceToken,
      currentClient: clerk.authoritativeClient,
      currentServerDate: lastServerDate
    ) else {
      return
    }
    guard responseCanBeAccepted(
      identity.client,
      responseSequence: context.responseSequence,
      serverDate: context.serverDate,
      clientResponseGeneration: context.clientResponseGeneration,
      clerk: clerk
    ) else {
      return
    }

    let deviceTokenChanged = currentDeviceToken != identity.deviceToken
    try persistLegacyIdentity(identity, clerk: clerk)
    applyIdentityToMemory(
      identity,
      clerk: clerk,
      fenceAllClientResponses: deviceTokenChanged,
      emitIdentityChange: true,
      fenceTokenChange: false
    )
    responseOrderingGate.record(sequence: context.responseSequence)
  }

  private func persistLegacyIdentity(
    _ identity: ClerkIdentitySnapshot,
    clerk: Clerk
  ) throws {
    let identity = try identity.validated()
    if let deviceToken = identity.deviceToken {
      try clerk.dependencies.identityKeychain.set(
        deviceToken,
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      )
    } else {
      try clerk.dependencies.identityKeychain.deleteItem(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      )
    }
  }

  private func applyIdentityToMemory(
    _ identity: ClerkIdentitySnapshot,
    clerk: Clerk,
    fenceAllClientResponses: Bool,
    emitIdentityChange: Bool,
    fenceTokenChange: Bool = true
  ) {
    let previousToken = currentDeviceToken
    if fenceAllClientResponses || (fenceTokenChange && previousToken != identity.deviceToken) {
      fenceClientResponses()
    }
    withApplyingIdentityTransition {
      isClientProvisional = false
      if identity.state == .cleared, identity.serverDate == nil {
        lastServerDate = identity.serverDate
      } else {
        recordAcceptedServerDate(identity.serverDate)
      }
      clerk.setClientFromIdentityController(identity.client)
    }
    if emitIdentityChange {
      clerk.emitInternalStateChange(.identityDidChange)
    }
  }

  private func setClient(_ client: Client?, on clerk: Clerk) {
    isClientProvisional = false
    withApplyingIdentityTransition {
      clerk.setClientFromIdentityController(client)
    }
  }

  private func withApplyingIdentityTransition(_ operation: () -> Void) {
    let previousApplyingState = isApplyingIdentityTransition
    isApplyingIdentityTransition = true
    defer { isApplyingIdentityTransition = previousApplyingState }
    operation()
  }

  private func recordAcceptedServerDate(_ serverDate: Date?) {
    responseOrderingGate.advanceServerDateWatermark(to: serverDate)
  }

  private func responseCanBeAccepted(
    _ incoming: Client?,
    responseSequence: Int?,
    serverDate: Date?,
    clientResponseGeneration: ClientResponseGeneration?,
    clerk: Clerk
  ) -> Bool {
    if let clientResponseGeneration,
       clientResponseGeneration != self.clientResponseGeneration
    {
      ClerkLogger.debug(
        "Ignoring client response from stale device token generation. Current generation: \(self.clientResponseGeneration), incoming generation: \(clientResponseGeneration)"
      )
      return false
    }

    guard responseOrderingGate.accepts(
      sequence: responseSequence,
      serverDate: serverDate,
      incomingUpdatedAt: incoming?.updatedAt,
      currentUpdatedAt: clerk.authoritativeClient?.updatedAt
    ) else {
      ClerkLogger.debug(
        "Ignoring stale client response. Current sequence: \(String(describing: responseOrderingGate.lastAcceptedSequence)), incoming sequence: \(String(describing: responseSequence))"
      )
      return false
    }
    return true
  }
}
