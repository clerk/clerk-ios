@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Security
import Testing

@MainActor
@Suite(.serialized)
struct IdentityClearOrderingTests {
  enum ClearObservationTiming: CaseIterable {
    case reconcile, restart, afterSignIn
  }

  @Test(arguments: [1, 2, 5], ClearObservationTiming.allCases)
  func siblingWatchClearAdvancesEachAppsCounterOnce(counter: Int, timing: ClearObservationTiming) throws {
    let shared = InMemoryKeychain()
    let first = try makeApp(shared: shared, local: InMemoryKeychain(), counter: counter)
    try first.seedIdentity(deviceToken: "old-token", client: .mock)
    let sibling = try makeApp(shared: shared, local: InMemoryKeychain(), counter: 1)
    let oldWatch = try WatchSyncState(of: first)
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    coordinator.apply(WatchSyncPayload(state: WatchSyncState(
      deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 2
    ), environment: nil), from: .watch, to: sibling)
    try #require(sibling.deviceToken == nil)
    if timing == .afterSignIn {
      try sibling.seedIdentity(deviceToken: "new-token", client: .mock)
    }
    let winner = try #require(try sibling.dependencies.identityStore.load())
    let observing: Clerk
    if timing == .restart {
      observing = Clerk()
      observing.dependencies = first.dependencies
      observing.identityController.hydrate()
    } else {
      observing = first
      #expect(observing.identityController.reconcileWithStore())
    }

    let expectedGeneration = max(counter + 1, 2)
    #expect(try WatchSyncState(of: observing).clearGeneration == expectedGeneration)
    coordinator.apply(WatchSyncPayload(state: oldWatch, environment: nil), from: .watch, to: observing)
    #expect(observing.deviceToken == winner.identity.deviceToken)
    #expect(try observing.dependencies.identityStore.load() == winner)
    #expect(!observing.identityController.reconcileWithStore())
    observing.identityController.hydrate()
    #expect(try WatchSyncState(of: observing).clearGeneration == expectedGeneration)

    let restarted = Clerk()
    restarted.dependencies = observing.dependencies
    restarted.identityController.hydrate()
    #expect(try WatchSyncState(of: restarted).clearGeneration == expectedGeneration)
    // A different clear must still increment, even though the shared record retains
    // the previous Watch generation and the app has already acknowledged that epoch.
    try restarted.identityController.clearIdentity()
    #expect(try WatchSyncState(of: restarted).clearGeneration == expectedGeneration + 1)
  }

  @Test(arguments: [false, true], [false, true])
  func unseenSharedClearRecoversWithoutRecounting(restarted: Bool, failObservationWrite: Bool) async throws {
    let shared = InMemoryKeychain()
    let local = FailingConditionalKeychain()
    let first = try makeApp(shared: shared, local: local, counter: 5)
    try first.seedIdentity(deviceToken: "old-token", client: .mock)
    let sibling = try makeApp(shared: shared, local: InMemoryKeychain(), counter: 1)
    let oldWatch = try WatchSyncState(of: first)
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    coordinator.apply(WatchSyncPayload(state: WatchSyncState(
      deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 2
    ), environment: nil), from: .watch, to: sibling)
    let cleared = try #require(try sibling.dependencies.identityStore.load())
    if failObservationWrite {
      local.failingSetKey = "\(first.dependencies.identityStore.clearIntentKey).watchClear"
    } else {
      local.failMarkerWrite = true
    }

    #expect(!first.identityController.reconcileWithStore())
    #expect(!first.identityController.canPublishIdentity)
    coordinator.sync(from: first)
    #expect(transport.sent.isEmpty)
    coordinator.apply(WatchSyncPayload(state: oldWatch, environment: nil), from: .watch, to: first)
    #expect(try first.dependencies.identityStore.load() == cleared)
    #expect(try WatchSyncState(of: first).clearGeneration == 5)

    local.failMarkerWrite = false
    local.failingSetKey = nil
    let recovered: Clerk
    if restarted {
      recovered = Clerk()
      recovered.dependencies = first.dependencies
      recovered.identityController.hydrate()
    } else {
      recovered = first
      _ = try await recovered.identityController.captureRequestIdentity()
    }
    #expect(recovered.identityController.canPublishIdentity)
    #expect(recovered.deviceToken == nil)
    #expect(try WatchSyncState(of: recovered).clearGeneration == 6)
    recovered.identityController.hydrate()
    #expect(try WatchSyncState(of: recovered).clearGeneration == 6)
    coordinator.apply(WatchSyncPayload(state: oldWatch, environment: nil), from: .watch, to: recovered)
    #expect(try recovered.dependencies.identityStore.load() == cleared)
  }

  private func makeApp(shared: any KeychainStorage, local: any KeychainStorage, counter: Int) throws -> Clerk {
    let clerk = Clerk()
    try local.set(String(counter), forKey: ClerkKeychainKey.watchSyncClearGeneration.rawValue)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope), appLocalKeychain: local, identityKeychain: shared
    )
    clerk.identityController.hydrate()
    return clerk
  }

  @Test
  func publicClearDoesNotAdvanceWatchGenerationUntilTheIdentityCommits() throws {
    let storage = FailingConditionalKeychain()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      appLocalKeychain: InMemoryKeychain(), identityKeychain: storage
    )
    try clerk.seedIdentity(deviceToken: "old-token", client: .mock)
    let generation = try WatchSyncState(of: clerk).clearGeneration
    storage.failWrites = true

    #expect(throws: (any Error).self) { try clerk.clearKeychainItems() }
    #expect(clerk.deviceToken == nil)
    #expect(try WatchSyncState(of: clerk).clearGeneration == generation)

    storage.failWrites = false
    let restarted = Clerk()
    restarted.dependencies = clerk.dependencies
    restarted.identityController.hydrate()
    #expect(restarted.deviceToken == nil)
    #expect(try WatchSyncState(of: restarted).clearGeneration > generation)
  }

  @Test
  func phoneClearStillAppliesAfterIdentityWriteFailure() throws {
    let storage = FailingConditionalKeychain()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      appLocalKeychain: InMemoryKeychain(), identityKeychain: storage
    )
    try clerk.seedIdentity(deviceToken: "old-token", client: .mock, serverDate: Date(timeIntervalSince1970: 100))
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    let clear = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 1)
    storage.failWrites = true
    coordinator.apply(WatchSyncPayload(state: clear, environment: nil), from: .phone, to: clerk)
    storage.failWrites = false
    coordinator.apply(WatchSyncPayload(state: clear, environment: nil), from: .phone, to: clerk)
    #expect(clerk.deviceToken == nil)
    #expect(clerk.client == nil)
    #expect(try !WatchSyncState(of: clerk).supersedes(clear, from: .watch))
  }

  @Test
  func explicitServerClearInSameSecondAsPeerUpdateApplies() async throws {
    let storage = InMemoryKeychain()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      appLocalKeychain: InMemoryKeychain(), identityKeychain: storage
    )
    try clerk.seedIdentity(deviceToken: "old-token", client: .mock, serverDate: Date(timeIntervalSince1970: 100))
    let store = clerk.dependencies.identityStore
    try store.save(ClerkIdentitySnapshot(
      state: .present, deviceToken: "old-token", client: .mock, serverDate: Date(timeIntervalSince1970: 200)
    ), replacing: store.load())
    #expect(clerk.identityController.reconcileWithStore())
    try await clerk.identityController.applyNetworkResponse(ClientSyncResponseContext(
      update: .explicitClear, deviceTokenUpdate: .clear, requestDeviceToken: "old-token",
      serverDate: Date(timeIntervalSince1970: 200), isCanonicalClientRequest: false,
      clientResponseGeneration: clerk.clientResponseGeneration, responseSequence: 10
    ))
    #expect(clerk.deviceToken == nil)
    #expect(clerk.client == nil)
    #expect(try store.load()?.identity.deviceToken == nil)
  }

  @Test(arguments: [false, true])
  func committedWatchGenerationRecoversAfterPrivateMarkerFailure(recreated: Bool) throws {
    let storage = FailingConditionalKeychain()
    let local = FailingConditionalKeychain()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      appLocalKeychain: local, identityKeychain: storage
    )
    try clerk.seedIdentity(deviceToken: "old-token", client: .mock, serverDate: Date(timeIntervalSince1970: 100))
    try local.set("0", forKey: ClerkKeychainKey.watchSyncClearGeneration.rawValue)
    local.failMarkerWrite = true
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    let clear = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 7)

    coordinator.apply(WatchSyncPayload(state: clear, environment: nil), from: .phone, to: clerk)

    #expect(clerk.deviceToken == nil)
    #expect(try WatchSyncState(of: clerk).client == nil)
    let store = clerk.dependencies.identityStore
    #expect(try store.load()?.identity.deviceToken == nil)
    #expect(try store.load()?.watchClearGeneration == 7)
    if recreated {
      try store.save(ClerkIdentitySnapshot(state: .present, deviceToken: "new-token", client: .mock, serverDate: nil))
    }
    local.failMarkerWrite = false
    let restarted = Clerk()
    restarted.dependencies = clerk.dependencies
    restarted.identityController.hydrate()

    #expect(restarted.deviceToken == (recreated ? "new-token" : nil))
    #expect(try WatchSyncState(of: restarted).clearGeneration == 7)
    coordinator.apply(WatchSyncPayload(state: clear, environment: nil), from: .phone, to: restarted)
    #expect(restarted.deviceToken == (recreated ? "new-token" : nil))
  }

  @Test
  func conflictingWatchWriteDoesNotAdvanceTheWinnersGeneration() throws {
    let storage = FailingConditionalKeychain()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      appLocalKeychain: InMemoryKeychain(), identityKeychain: storage
    )
    try clerk.seedIdentity(deviceToken: "old-token", client: .mock, serverDate: Date(timeIntervalSince1970: 100))
    let store = clerk.dependencies.identityStore
    storage.beforeWrite = {
      try store.save(ClerkIdentitySnapshot(state: .present, deviceToken: "winner", client: .mock, serverDate: nil))
    }
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    coordinator.apply(WatchSyncPayload(
      state: WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 7), environment: nil
    ), from: .phone, to: clerk)

    #expect(clerk.deviceToken == "winner")
    #expect(try WatchSyncState(of: clerk).clearGeneration == 0)
    #expect(try store.load()?.watchClearGeneration == nil)
  }
}

private final class FailingConditionalKeychain: KeychainStorage, @unchecked Sendable {
  let backing = InMemoryKeychain()
  var failWrites = false
  var failReads = false
  var failMarkerWrite = false
  var failingSetKey: String?
  var beforeWrite: (() throws -> Void)?
  func set(_ data: Data, forKey key: String) throws {
    if key == failingSetKey { throw KeychainError.unexpectedStatus(errSecInteractionNotAllowed) }
    if failMarkerWrite, key == ClerkKeychainKey.watchSyncClearGeneration.rawValue {
      throw KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
    }
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    if failReads { throw KeychainError.unexpectedStatus(errSecInteractionNotAllowed) }
    return try backing.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }

  func compareAndSwap(_ data: Data, forKey key: String, expectedRevision: UUID?, newRevision: UUID) throws -> Bool {
    let action = beforeWrite
    beforeWrite = nil
    try action?()
    if failWrites { throw KeychainError.unexpectedStatus(errSecInteractionNotAllowed) }
    return try backing.compareAndSwap(data, forKey: key, expectedRevision: expectedRevision, newRevision: newRevision)
  }
}
