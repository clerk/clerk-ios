@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Security
import Testing

@MainActor
@Suite(.serialized)
struct IdentityClearOrderingTests {
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
  var beforeWrite: (() throws -> Void)?
  func set(_ data: Data, forKey key: String) throws {
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
