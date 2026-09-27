@_spi(FrameworkIntegration) @testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Security
import Testing

@MainActor
@Suite(.serialized)
struct IdentityCoordinationTests {
  @Test
  func concurrentCreationNeverOverwritesTheWinner() throws {
    let store = makeStore()
    let winner = try store.save(identity("first"), replacing: nil)
    #expect(throws: ClerkIdentityStoreError.writeConflict) {
      try store.save(identity("second"), replacing: nil)
    }
    #expect(try store.load() == winner)
  }

  @Test
  func oldSnapshotCannotOverwriteAClearOrRecreatedIdentity() throws {
    let store = makeStore()
    let original = try store.save(identity("token"), replacing: nil)
    let cleared = try store.clear()
    #expect(cleared.identity == .signedOut)
    #expect(cleared.epoch != original.epoch)
    #expect(throws: ClerkIdentityStoreError.writeConflict) {
      try store.save(identity("token"), replacing: original)
    }
    let recreated = try store.save(identity("token"), replacing: cleared)
    #expect(recreated.epoch != original.epoch)
    #expect(throws: ClerkIdentityStoreError.writeConflict) {
      try store.save(identity("token"), replacing: original)
    }
    #expect(try store.load() == recreated)
  }

  @Test
  func concurrentConditionalUpdatesLoseNoAcceptedWrites() async throws {
    let store = makeStore()
    try store.save(identity("token", date: 0), replacing: nil)
    try await withThrowingTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 2 {
        group.addTask {
          var successes = 0
          for _ in 0 ..< 2000 {
            if successes == 100 { return }
            let current = try #require(try store.load())
            await Task.yield()
            let next = ClerkIdentitySnapshot(
              state: .cleared, deviceToken: "token", client: nil,
              serverDate: current.identity.serverDate!.addingTimeInterval(1)
            )
            do {
              try store.save(next, replacing: current)
              successes += 1
            } catch ClerkIdentityStoreError.writeConflict { continue }
          }
          Issue.record("Conditional writes did not make progress")
        }
      }
      try await group.waitForAll()
    }
    #expect(try store.load()?.identity.serverDate == Date(timeIntervalSince1970: 200))
  }

  @Test
  func peerClearBetweenResponseValidationAndWriteCannotBeUndone() async throws {
    let (clerk, storage) = try makeClerk()
    let store = clerk.dependencies.identityStore
    let response = context(clerk, date: 200)
    storage.beforeWrite = { _ = try store.clear() }

    try await clerk.identityController.applyNetworkResponse(response)

    #expect(try store.load()?.identity == .signedOut)
    #expect(clerk.deviceToken == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func missedClearAndSameTokenRecreationStillFenceTheOldRequest() async throws {
    let (clerk, _) = try makeClerk()
    let response = context(clerk, date: 900)
    let store = clerk.dependencies.identityStore
    let cleared = try store.clear()
    try store.save(identity("token", date: 200), replacing: cleared)

    try await clerk.identityController.applyNetworkResponse(response)

    #expect(try store.load()?.identity.serverDate == Date(timeIntervalSince1970: 200))
    #expect(clerk.client == nil)
  }

  @Test(arguments: [200.0, 400.0])
  func conflictingCanonicalReadAdoptsThePeerWithoutRetrying(responseDate: Double) async throws {
    let (clerk, storage) = try makeClerk()
    let store = clerk.dependencies.identityStore
    let response = context(clerk, date: responseDate)
    storage.beforeWrite = {
      try store.save(ClerkIdentitySnapshot(
        state: .present, deviceToken: "token", client: .mockSignedOut,
        serverDate: Date(timeIntervalSince1970: 300)
      ), replacing: store.load())
    }

    try await clerk.identityController.applyNetworkResponse(response)

    #expect(try store.load()?.identity.serverDate == Date(timeIntervalSince1970: 300))
    #expect(clerk.client?.sessions.isEmpty == true)
  }

  @Test
  func sameSecondPeerSnapshotRejectsAnOlderClient() async throws {
    let (clerk, _) = try makeClerk()
    var peer = Client.mock
    peer.updatedAt = Date(timeIntervalSince1970: 20)
    try clerk.dependencies.identityStore.save(ClerkIdentitySnapshot(
      state: .present, deviceToken: "token", client: peer, serverDate: Date(timeIntervalSince1970: 200)
    ))
    var stale = peer
    stale.updatedAt = Date(timeIntervalSince1970: 10)
    try await clerk.identityController.applyNetworkResponse(context(clerk, date: 200, client: stale))

    #expect(clerk.client?.updatedAt == peer.updatedAt)
    #expect(try clerk.dependencies.identityStore.load()?.identity.client?.updatedAt == peer.updatedAt)
  }

  @Test
  func inaccessibleSharedStoragePreventsRequestPreparation() async throws {
    let (clerk, storage) = try makeClerk()
    storage.readError = KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
    await #expect(throws: (any Error).self) {
      try await clerk.identityController.captureRequestIdentity()
    }
  }

  @Test
  func clearConflictMakesOneAttemptAndRequiresAnExplicitRetry() async throws {
    let (clerk, storage) = try makeClerk()
    let store = clerk.dependencies.identityStore
    storage.beforeWrite = {
      try store.save(ClerkIdentitySnapshot(state: .cleared, deviceToken: "peer-token", client: nil, serverDate: nil), replacing: store.load())
    }
    #expect(throws: ClerkIdentityStoreError.writeConflict) {
      try clerk.identityController.clearIdentity()
    }
    #expect(try store.load()?.identity.deviceToken == "peer-token")
    #expect(clerk.deviceToken == nil)
    await #expect(throws: ClerkIdentityStoreError.clearPending) {
      try await clerk.identityController.captureRequestIdentity()
    }

    try clerk.identityController.clearIdentity()

    #expect(try store.load()?.identity == .signedOut)
    #expect(try await clerk.identityController.captureRequestIdentity().deviceToken == nil)
  }

  @Test
  func conflictingExternalTransitionDoesNotRunCompletion() throws {
    let (clerk, storage) = try makeClerk()
    let store = clerk.dependencies.identityStore
    storage.beforeWrite = { _ = try store.clear() }
    var completed = false
    #expect(throws: ClerkIdentityStoreError.writeConflict) {
      try clerk.identityController.applyExternalTransition {
        .init(identity: identity("watch-token"), didApply: { completed = true })
      }
    }
    #expect(!completed)
    #expect(try store.load()?.identity == .signedOut)
  }

  @Test
  func identityPublicationDoesNotSharePrivateState() async throws {
    let (clerk, _) = try makeClerk()
    let privateStorage = clerk.dependencies.appLocalKeychain
    try privateStorage.set("app-attest-id", forKey: ClerkKeychainKey.attestKeyId.rawValue)
    try privateStorage.set("pkce-secret", forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue)
    try await clerk.identityController.applyNetworkResponse(context(clerk, date: 200))

    let shared = clerk.dependencies.identityStore.keychain
    #expect(try shared.data(forKey: ClerkKeychainKey.attestKeyId.rawValue) == nil)
    #expect(try shared.data(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == nil)
    let record = try #require(try shared.data(forKey: clerk.dependencies.identityStore.key))
    #expect(!String(decoding: record, as: UTF8.self).contains("pkce-secret"))
    #expect(try privateStorage.string(forKey: ClerkKeychainKey.attestKeyId.rawValue) == "app-attest-id")
  }

  @Test
  func conflictingMutationRefreshesOnceAndResolvesItsOwnedCompletion() async throws {
    let service = RecoveryClientService()
    let (clerk, storage) = try makeClerk(clientService: service.service)
    clerk.setClientFromIdentityController(.mockSignedOut)
    clerk.environment = .mock
    let registration = try #require(clerk.registerAuthFlow())
    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = Client.mock.currentSession?.id
    storage.beforeWrite = {
      try clerk.dependencies.identityStore.save(ClerkIdentitySnapshot(
        state: .present, deviceToken: "token", client: .mockSignedOut,
        serverDate: Date(timeIntervalSince1970: 300)
      ))
    }

    try await clerk.identityController.applyNetworkResponse(context(
      clerk, date: 400, canonical: false, completion: .signIn(signIn), ownerID: registration.id
    ))

    #expect(service.reads == 1)
    #expect(clerk.client?.currentSession?.id == signIn.createdSessionId)
    let snapshot = try #require(clerk.authFlowSnapshot(for: registration))
    guard case .awaiting(_, let completion) = snapshot.phase else {
      Issue.record("Expected the recovered sign-in to await its owned post-auth work")
      return
    }
    #expect(completion?.flowId == signIn.id)
    withExtendedLifetime(registration) {}
  }

  @Test
  func failedRecoveryReadDoesNotTurnASuccessfulMutationIntoARetry() async throws {
    let service = RecoveryClientService()
    service.failure = URLError(.notConnectedToInternet)
    let (clerk, storage) = try makeClerk(clientService: service.service)
    storage.beforeWrite = {
      try clerk.dependencies.identityStore.save(ClerkIdentitySnapshot(
        state: .present, deviceToken: "token", client: .mockSignedOut,
        serverDate: Date(timeIntervalSince1970: 300)
      ))
    }

    try await clerk.identityController.applyNetworkResponse(context(clerk, date: 400, canonical: false))

    #expect(service.reads == 1)
    #expect(clerk.client?.sessions.isEmpty == true)
  }

  @Test
  func peerClearDoesNotFetchOrRecreateAnIdentityDuringMutationRecovery() async throws {
    let service = RecoveryClientService()
    let (clerk, storage) = try makeClerk(clientService: service.service)
    storage.beforeWrite = { _ = try clerk.dependencies.identityStore.clear() }

    try await clerk.identityController.applyNetworkResponse(context(clerk, date: 400, canonical: false))

    #expect(service.reads == 0)
    #expect(clerk.deviceToken == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func anUncommittedClearDoesNotPublishWatchState() throws {
    let (clerk, storage) = try makeClerk()
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    clerk.internalStateChanges.addObserver(coordinator)
    let previousGeneration = try WatchSyncClearMarker.generation(in: clerk.dependencies.watchSyncKeychain)
    storage.writeError = KeychainError.unexpectedStatus(errSecInteractionNotAllowed)

    #expect(throws: (any Error).self) { try clerk.identityController.clearIdentity() }
    coordinator.sync(from: clerk)
    #expect(transport.sent.isEmpty)

    storage.writeError = nil
    try clerk.identityController.clearIdentity()
    let state = try #require(transport.sent.last?.state)
    #expect(state.deviceToken == nil)
    #expect(state.clearGeneration > previousGeneration)
    #expect(try clerk.dependencies.identityStore.load()?.identity == .signedOut)
  }

  @Test
  func failedClearIsRecoveredBeforeANewRuntimeHydratesCredentials() async throws {
    let (clerk, storage) = try makeClerk()
    let store = clerk.dependencies.identityStore
    storage.writeError = KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
    #expect(throws: (any Error).self) { try clerk.identityController.clearIdentity() }
    #expect(try clerk.dependencies.appLocalKeychain.hasItem(forKey: store.clearIntentKey))
    #expect(try storage.data(forKey: store.clearIntentKey) == nil)

    let restarted = Clerk()
    restarted.dependencies = clerk.dependencies
    restarted.identityController.hydrate()
    await #expect(throws: (any Error).self) { try await restarted.identityController.captureRequestIdentity() }
    #expect(restarted.client == nil)

    storage.writeError = nil
    #expect(try await restarted.identityController.captureRequestIdentity().deviceToken == nil)
    #expect(try store.load()?.identity == .signedOut)
    #expect(try !clerk.dependencies.appLocalKeychain.hasItem(forKey: store.clearIntentKey))
  }

  @Test
  func recoveringAnOldClearPreservesALaterIdentityEpoch() throws {
    let (clerk, storage) = try makeClerk()
    let store = clerk.dependencies.identityStore
    storage.writeError = KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
    #expect(throws: (any Error).self) { try clerk.identityController.clearIdentity() }
    storage.writeError = nil
    try store.save(identity("new-token"))

    let restarted = Clerk()
    restarted.dependencies = clerk.dependencies
    restarted.identityController.hydrate()

    #expect(restarted.deviceToken == "new-token")
    #expect(try store.load()?.identity.deviceToken == "new-token")
    #expect(try !clerk.dependencies.appLocalKeychain.hasItem(forKey: store.clearIntentKey))
  }

  @Test
  func anUnreadableIdentityStillLeavesADurableClearIntent() throws {
    let (clerk, storage) = try makeClerk()
    storage.readError = KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
    #expect(throws: (any Error).self) { try clerk.identityController.clearIdentity() }
    storage.readError = nil

    let restarted = Clerk()
    restarted.dependencies = clerk.dependencies
    restarted.identityController.hydrate()

    #expect(restarted.deviceToken == nil)
    #expect(try clerk.dependencies.identityStore.load()?.identity == .signedOut)
  }

  @Test
  func lockedMigrationIsRetriedBeforePreparingAnyRequest() async throws {
    let storage = InterleavingIdentityKeychain()
    try storage.set("legacy-token", forKey: "legacy")
    let store = ClerkIdentityStore(keychain: storage, instanceFingerprint: "")
    let preparation = ClerkIdentityStore.Preparation {
      let token = try #require(try storage.string(forKey: "legacy"))
      try store.save(ClerkIdentitySnapshot(state: .cleared, deviceToken: token, client: nil, serverDate: nil), replacing: nil)
    }
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope), identityKeychain: storage,
      identityPreparation: preparation
    )
    storage.readError = KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
    clerk.identityController.hydrate()
    await #expect(throws: (any Error).self) { try await clerk.identityController.captureRequestIdentity() }
    #expect(clerk.deviceToken == nil)
    storage.readError = nil

    #expect(try await clerk.identityController.captureRequestIdentity().deviceToken == "legacy-token")
    // Preparation runs once after success; it does not attempt another creation.
    #expect(try await clerk.identityController.captureRequestIdentity().deviceToken == "legacy-token")
  }

  @Test(arguments: [false, true])
  func siblingClearFencesOldWatchStateEvenWhenTheTombstoneWasMissed(recreated: Bool) throws {
    let (clerk, _) = try makeClerk()
    let oldWatchState = try WatchSyncState(of: clerk)
    let store = clerk.dependencies.identityStore
    try store.clear()
    if recreated { try store.save(identity("token", date: 200)) }

    #expect(clerk.identityController.reconcileWithStore())
    let generation = try WatchSyncState(of: clerk).clearGeneration
    #expect(generation > oldWatchState.clearGeneration)
    let watch = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    watch.apply(WatchSyncPayload(state: oldWatchState, environment: nil), from: .watch, to: clerk)
    #expect(clerk.client == nil)
    #expect(clerk.deviceToken == (recreated ? "token" : nil))

    let restarted = Clerk()
    restarted.dependencies = clerk.dependencies
    restarted.identityController.hydrate()
    #expect(try WatchSyncState(of: restarted).clearGeneration == generation)
  }

  @Test
  func serverClearAdvancesTheWatchFenceBeforePublishingState() async throws {
    let (clerk, _) = try makeClerk()
    let old = try WatchSyncState(of: clerk)

    try await clerk.identityController.applyNetworkResponse(ClientSyncResponseContext(
      update: .explicitClear, deviceTokenUpdate: .clear, requestDeviceToken: "token",
      serverDate: Date(timeIntervalSince1970: 200), isCanonicalClientRequest: false,
      clientResponseGeneration: clerk.clientResponseGeneration, responseSequence: 1
    ))

    #expect(try WatchSyncState(of: clerk).clearGeneration > old.clearGeneration)
    #expect(try WatchSyncState(of: clerk).supersedes(old, from: .phone))
  }

  @Test
  func realPipelineDoesNotRepeatAMutationOrReapplyAConflictingRead() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let storage = InterleavingIdentityKeychain()
    let apiClient = createMockAPIClient(runtimeScope: clerk.runtimeScope)
    clerk.dependencies = MockDependencyContainer(
      apiClient: apiClient, appLocalKeychain: InMemoryKeychain(), identityKeychain: storage,
      sharesIdentity: true, clientService: ClientService(apiClient: apiClient)
    )
    try clerk.seedIdentity(deviceToken: "token", client: .mock, serverDate: Date(timeIntervalSince1970: 100))
    clerk.identityController.startSharing(notifier: SilentIdentityNotifier())
    let writes = LockIsolated(0)
    let reads = LockIsolated(0)
    var mutation = try Mock(
      url: mockBaseUrl.appendingPathComponent("v1/sync-recovery-mutation"), ignoreQuery: true,
      contentType: .json, statusCode: 200,
      data: [.post: JSONEncoder.clerkEncoder.encode(ClientResponse(response: EmptyResponse(), client: .mock))],
      additionalHeaders: ["Date": "Thu, 01 Jan 1970 00:06:40 GMT"]
    )
    mutation.onRequestHandler = OnRequestHandler { @Sendable _ in writes.withValue { $0 += 1 } }
    mutation.register()
    var read = try Mock(
      url: mockBaseUrl.appendingPathComponent("v1/client"), ignoreQuery: true,
      contentType: .json, statusCode: 200,
      data: [.get: JSONEncoder.clerkEncoder.encode(ClientResponse<Client?>(response: .mock, client: nil))],
      additionalHeaders: ["Date": "Thu, 01 Jan 1970 00:08:20 GMT"]
    )
    read.onRequestHandler = OnRequestHandler { @Sendable _ in reads.withValue { $0 += 1 } }
    read.register()
    let store = clerk.dependencies.identityStore
    storage.beforeWrite = {
      try store.save(ClerkIdentitySnapshot(
        state: .present, deviceToken: "token", client: .mockSignedOut, serverDate: Date(timeIntervalSince1970: 300)
      ))
      // The recovery GET also loses its write. Its decoded response must not
      // subsequently be rebased by refreshClient against this new revision.
      storage.beforeWrite = {
        try store.save(ClerkIdentitySnapshot(
          state: .present, deviceToken: "token", client: .mockSignedOut, serverDate: Date(timeIntervalSince1970: 450)
        ))
      }
    }

    _ = try await apiClient.send(Request<EmptyResponse>(path: "/v1/sync-recovery-mutation", method: .post))

    #expect(writes.value == 1)
    #expect(reads.value == 1)
    #expect(clerk.client?.sessions.isEmpty == true)
    #expect(try store.load()?.identity.serverDate == Date(timeIntervalSince1970: 450))
  }

  private func makeStore() -> ClerkIdentityStore {
    ClerkIdentityStore(keychain: InMemoryKeychain(), instanceFingerprint: "instance")
  }

  private func identity(_ token: String, date: TimeInterval = 100) -> ClerkIdentitySnapshot {
    ClerkIdentitySnapshot(state: .cleared, deviceToken: token, client: nil, serverDate: Date(timeIntervalSince1970: date))
  }

  private func makeClerk(clientService: (any ClientServiceProtocol)? = nil) throws -> (Clerk, InterleavingIdentityKeychain) {
    let storage = InterleavingIdentityKeychain()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      appLocalKeychain: InMemoryKeychain(), identityKeychain: storage, sharesIdentity: true,
      clientService: clientService
    )
    try clerk.seedIdentity(deviceToken: "token", client: .mock, serverDate: Date(timeIntervalSince1970: 100))
    clerk.identityController.startSharing(notifier: SilentIdentityNotifier())
    return (clerk, storage)
  }

  private func context(
    _ clerk: Clerk, date: TimeInterval, client: Client = .mock, canonical: Bool = true,
    completion: TransferFlowResult? = nil, ownerID: UUID? = nil
  ) -> ClientSyncResponseContext {
    ClientSyncResponseContext(
      update: .client(client), deviceTokenUpdate: .absent, requestDeviceToken: "token",
      serverDate: Date(timeIntervalSince1970: date), isCanonicalClientRequest: canonical,
      clientResponseGeneration: clerk.clientResponseGeneration, responseSequence: 10,
      completedAuthFlow: completion, authFlowRegistrationId: ownerID
    )
  }
}

@MainActor
private final class RecoveryClientService {
  var reads = 0
  var failure: (any Error)?
  lazy var service: MockClientService = {
    let service = MockClientService()
    service.responseHandler = { [unowned self] request in
      #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == nil)
      reads += 1
      if let failure { throw failure }
      return .init(client: .mock, serverDate: Date(timeIntervalSince1970: 500))
    }
    return service
  }()
}

/// Models another process writing precisely between the controller's read and conditional write.
private final class InterleavingIdentityKeychain: KeychainStorage, @unchecked Sendable {
  let backing = InMemoryKeychain()
  var beforeWrite: (() throws -> Void)?
  var readError: (any Error)?
  var writeError: (any Error)?

  func compareAndSwap(_ data: Data, forKey key: String, expectedRevision: UUID?, newRevision: UUID) throws -> Bool {
    let action = beforeWrite
    beforeWrite = nil
    try action?()
    if let writeError { throw writeError }
    return try backing.compareAndSwap(data, forKey: key, expectedRevision: expectedRevision, newRevision: newRevision)
  }

  func set(_ data: Data, forKey key: String) throws {
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    if let readError { throw readError }
    return try backing.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }
}

@MainActor
private final class SilentIdentityNotifier: SharedSessionSyncNotifying {
  func setHandler(_: @escaping @MainActor () -> Void) {}
  func post() {}
}
