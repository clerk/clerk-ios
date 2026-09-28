@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct IdentityHydrationRecoveryTests {
  @Test
  func failedPhoneHydrationDoesNotPublishAClearAndResumesAfterRecovery() throws {
    let storage = HydrationKeychain()
    let local = InMemoryKeychain()
    let phone = Clerk()
    phone.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: phone.runtimeScope), appLocalKeychain: local, identityKeychain: storage
    )
    try phone.dependencies.identityStore.save(.init(state: .present, deviceToken: "phone-token", client: .mock, serverDate: nil))
    try local.set("1", forKey: ClerkKeychainKey.watchSyncClearGeneration.rawValue)
    storage.isLocked = true
    phone.identityController.hydrate()
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    coordinator.sync(from: phone)

    let watch = makeApp(shared: InMemoryKeychain())
    try watch.seedIdentity(deviceToken: "watch-token", client: .mock)
    let watchCoordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    for payload in transport.sent {
      watchCoordinator.apply(payload, from: .phone, to: watch)
    }
    #expect(transport.sent.isEmpty)
    #expect(watch.deviceToken == "watch-token")

    storage.isLocked = false
    phone.identityController.hydrate()
    coordinator.sync(from: phone)
    let payload = try #require(transport.sent.last)
    #expect(payload.state?.deviceToken == "phone-token")
    #expect(payload.state?.clearGeneration == 1)
    watchCoordinator.apply(payload, from: .phone, to: watch)
    #expect(watch.deviceToken == "phone-token")
  }

  @Test
  func unreadableWatchGenerationDefersPublicationUntilRecovery() throws {
    let local = HydrationKeychain()
    let phone = Clerk()
    phone.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: phone.runtimeScope),
      appLocalKeychain: local, identityKeychain: InMemoryKeychain()
    )
    try phone.seedIdentity(deviceToken: "phone-token", client: .mock)
    try local.set("3", forKey: ClerkKeychainKey.watchSyncClearGeneration.rawValue)
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    local.isLocked = true
    coordinator.sync(from: phone)
    #expect(transport.sent.isEmpty)

    local.isLocked = false
    coordinator.sync(from: phone)
    #expect(transport.sent.last?.state?.deviceToken == "phone-token")
    #expect(transport.sent.last?.state?.clearGeneration == 3)
  }

  @Test
  func siblingClearMustRejectOldWatchIdentity() throws {
    let shared = InMemoryKeychain()
    let first = makeApp(shared: shared)
    try first.seedIdentity(deviceToken: "old-token", client: .mock, serverDate: Date(timeIntervalSince1970: 100))
    let second = makeApp(shared: shared)
    second.identityController.hydrate()
    let oldWatchState = try WatchSyncState(of: first)

    try second.clearKeychainItems()
    #expect(first.identityController.reconcileWithStore())
    #expect(first.client == nil)
    let watch = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    watch.apply(WatchSyncPayload(state: oldWatchState, environment: nil), from: .watch, to: first)

    #expect(first.deviceToken == nil)
    #expect(first.client == nil)
    #expect(try first.dependencies.identityStore.load()?.identity == .signedOut)
  }

  @Test
  func serverClearMustAdvanceWatchClearGeneration() async throws {
    let clerk = makeApp(shared: InMemoryKeychain())
    try clerk.seedIdentity(deviceToken: "old-token", client: .mock, serverDate: Date(timeIntervalSince1970: 100))
    let oldWatchState = try WatchSyncState(of: clerk)
    try await clerk.identityController.applyNetworkResponse(ClientSyncResponseContext(
      update: .explicitClear, deviceTokenUpdate: .clear, requestDeviceToken: "old-token",
      serverDate: Date(timeIntervalSince1970: 200), isCanonicalClientRequest: false,
      clientResponseGeneration: clerk.clientResponseGeneration, responseSequence: 1
    ))
    #expect(clerk.deviceToken == nil)
    #expect(try WatchSyncState(of: clerk).clearGeneration > oldWatchState.clearGeneration)
    #expect(try WatchSyncState(of: clerk).supersedes(oldWatchState, from: .phone))
  }

  @Test
  func restartingAfterPrivateAdoptionMustStillMigrateLegacyLogin() throws {
    let shared = InMemoryKeychain()
    let appLocal = InMemoryKeychain()
    let marker = InMemoryKeychain()
    try appLocal.set("existing-local-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try AppLocalStateAdoption(markerKeychain: marker, appLocal: appLocal, shared: shared).adoptIfNeeded()
    // The process exits here, before identity migration has created the V4 record.
    #expect(try AppLocalStateAdoption.usesAppLocalStorage(in: marker))
    let identityWasAdopted = try AppLocalStateAdoption.hasLegacyIdentityAdoption(in: marker)
    #expect(!identityWasAdopted)
    let store = ClerkIdentityStore(keychain: shared, instanceFingerprint: "review")
    var migration = ClerkIdentityMigration(
      store: store, legacyKeychain: shared, markerKeychain: appLocal,
      configuredService: "review", accessGroup: "TEAM.review", ownerIdentifier: "review.app",
      instanceFingerprint: "review", readsLegacyItems: !identityWasAdopted
    )
    migration.makeKeychain = { _, _ in InMemoryKeychain() }
    try migration.migrateIfNeeded()
    #expect(try store.load()?.identity.deviceToken == "existing-local-token")
    #expect(try appLocal.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "existing-local-token"
      || store.load()?.identity.deviceToken == "existing-local-token")
  }

  @Test
  func watchDecisionMustUseRecoveredPhoneIdentity() throws {
    let clerk = try makeAppAfterFailedHydration()
    let watch = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    var unrelatedClient = Client.mockSignedOut
    unrelatedClient.id = "unrelated-watch-client"
    watch.apply(WatchSyncPayload(
      state: WatchSyncState(deviceToken: "signed-out-watch-token", client: unrelatedClient,
                            serverDate: Date(timeIntervalSince1970: 200)), environment: nil
    ), from: .watch, to: clerk)
    #expect(clerk.deviceToken == "signed-in-phone-token")
    #expect(clerk.client?.sessions.isEmpty == false)
  }

  @Test
  func settingThePersistedTokenAfterFailedHydrationPreservesTheClient() async throws {
    let clerk = try makeAppAfterFailedHydration()

    let result = try await clerk.identityController.updateDeviceToken(to: "signed-in-phone-token")

    #expect(result == .unchanged)
    #expect(clerk.client?.sessions.isEmpty == false)
    #expect(try clerk.dependencies.identityStore.load()?.identity.client?.sessions.isEmpty == false)
  }

  @Test
  func tokenResponseAfterFailedHydrationPreservesTheRecoveredClient() async throws {
    let clerk = try makeAppAfterFailedHydration()
    try await clerk.identityController.applyNetworkResponse(ClientSyncResponseContext(
      update: .absent, deviceTokenUpdate: .set("refreshed-token"),
      requestDeviceToken: "signed-in-phone-token", serverDate: Date(timeIntervalSince1970: 200),
      isCanonicalClientRequest: false, clientResponseGeneration: clerk.clientResponseGeneration, responseSequence: 1
    ))

    #expect(clerk.deviceToken == "refreshed-token")
    #expect(clerk.client?.sessions.isEmpty == false)
    #expect(try clerk.dependencies.identityStore.load()?.identity.client?.sessions.isEmpty == false)
  }

  @Test
  func clientResponseAfterFailedHydrationKeepsTheRecoveredToken() async throws {
    let clerk = try makeAppAfterFailedHydration()
    try await clerk.applyResponseClient(.mockSignedOut, serverDate: Date(timeIntervalSince1970: 200))

    #expect(clerk.deviceToken == "signed-in-phone-token")
    #expect(clerk.client?.sessions.isEmpty == true)
    let persisted = try #require(try clerk.dependencies.identityStore.load()?.identity)
    #expect(persisted.deviceToken == "signed-in-phone-token")
    #expect(persisted.client?.sessions.isEmpty == true)
  }

  private func makeAppAfterFailedHydration() throws -> Clerk {
    let keychain = HydrationKeychain()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope), keychain: keychain
    )
    try clerk.dependencies.identityStore.save(ClerkIdentitySnapshot(
      state: .present, deviceToken: "signed-in-phone-token", client: .mock, serverDate: Date(timeIntervalSince1970: 100)
    ))
    keychain.isLocked = true
    clerk.identityController.hydrate()
    #expect(clerk.deviceToken == nil)
    keychain.isLocked = false
    return clerk
  }

  private func makeApp(shared: InMemoryKeychain) -> Clerk {
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope), keychain: shared,
      appLocalKeychain: InMemoryKeychain(), identityKeychain: shared, sharesIdentity: true
    )
    return clerk
  }
}

private final class HydrationKeychain: ForwardingTestKeychain, @unchecked Sendable {
  let backing = InMemoryKeychain()
  var isLocked = false
  func data(forKey key: String) throws -> Data? {
    if isLocked { throw KeychainError.unexpectedStatus(-25308) }
    return try backing.data(forKey: key)
  }

  func compareAndSwap(_ data: Data, forKey key: String, expectedRevision: UUID?, newRevision: UUID) throws -> Bool {
    try backing.compareAndSwap(data, forKey: key, expectedRevision: expectedRevision, newRevision: newRevision)
  }
}
