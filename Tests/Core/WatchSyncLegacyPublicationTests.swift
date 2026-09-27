@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Testing

struct WatchSyncLegacyPublicationTests {
  @Test
  @MainActor
  func failedFloorPreservationKeepsItsSourceUntilCleanupCanRetry() throws {
    let keychain = PublicationJournal()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope), keychain: keychain, identityKeychain: InMemoryKeychain()
    )
    try clerk.seedIdentity(deviceToken: "token", client: .mock)
    let metadata = try JSONSerialization.data(withJSONObject: ["auth_version": 500_000])
    try keychain.set(metadata, forKey: ClerkKeychainKey.watchSyncMetadata.rawValue)
    try keychain.set("private-attest", forKey: ClerkKeychainKey.attestKeyId.rawValue)
    keychain.failsFloorWrite = true
    #expect(throws: (any Error).self) { try clerk.clearKeychainItems() }
    #expect(clerk.deviceToken == nil)
    #expect(try keychain.data(forKey: ClerkKeychainKey.attestKeyId.rawValue) == nil)
    #expect(try keychain.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue) == metadata)
    keychain.failsFloorWrite = false
    try clerk.clearKeychainItems()
    #expect(try keychain.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue) == nil)
    let version = try #require(try WatchSyncLegacyPublication.version(
      for: WatchSyncState(of: clerk), store: clerk.dependencies.identityStore, legacyKeychain: keychain,
      now: Date(timeIntervalSince1970: 100)
    ))
    #expect(version > 500_000)
  }

  @Test(arguments: [false, true], [false, true])
  @MainActor
  func clearingBeforeFirstPublicationPreservesLegacyOrdering(atomicMetadata: Bool, reconfiguration: Bool) throws {
    let keychain = InMemoryKeychain()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope), keychain: keychain)
    try clerk.seedIdentity(deviceToken: "old-token", client: .mock)
    if atomicMetadata {
      try keychain.set(JSONSerialization.data(withJSONObject: [
        "device_token_version": 300_000, "auth_version": 400_000, "pending_auth_version": 500_000,
      ]), forKey: ClerkKeychainKey.watchSyncMetadata.rawValue)
    } else {
      try keychain.set("300000", forKey: ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue)
      try keychain.set("500000", forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue)
    }
    if reconfiguration {
      try Clerk.clearLocalClerkStorageStrictly(in: clerk.dependencies)
    } else {
      try clerk.clearKeychainItems()
    }
    let restarted = Clerk()
    restarted.dependencies = clerk.dependencies
    restarted.identityController.hydrate()
    let clear = try WatchSyncState(of: restarted)
    let version = try #require(try WatchSyncLegacyPublication.version(
      for: clear, store: restarted.dependencies.identityStore, legacyKeychain: keychain, now: Date(timeIntervalSince1970: 100)
    ))
    #expect(clear.isCleared)
    #expect(version > 500_000)
    #expect(try keychain.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue) == nil)
    try restarted.seedIdentity(deviceToken: "new-token", client: .mock)
    let loginVersion = try #require(try WatchSyncLegacyPublication.version(
      for: WatchSyncState(of: restarted), store: restarted.dependencies.identityStore,
      legacyKeychain: keychain, now: Date(timeIntervalSince1970: 50)
    ))
    #expect(loginVersion > version)
  }

  @Test
  func emptyInstallIsNotALegacyClearAndTokenOnlyStateStillRequestsAClient() throws {
    let keychain = InMemoryKeychain()
    let store = ClerkIdentityStore(keychain: keychain, instanceFingerprint: "instance")
    let empty = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil)
    #expect(try WatchSyncLegacyPublication.version(for: empty, store: store, legacyKeychain: keychain) == nil)
    let unresolved = WatchSyncState(deviceToken: "new-token", client: nil, serverDate: nil)
    let version = try #require(try WatchSyncLegacyPublication.version(for: unresolved, store: store, legacyKeychain: keychain))
    let context = WatchSyncPayload(state: unresolved, environment: nil, legacyVersion: .init(token: version, auth: version)).applicationContext
    #expect(context["watchSyncDeviceTokenState"] as? String == "set")
    #expect(context["watchSyncDeviceTokenVersion"] as? Int == version)
    #expect(context["watchSyncAuthState"] == nil)
    #expect(context["watchSyncAuthVersion"] == nil)
  }

  @Test
  func separateLegacyVersionsAndClockRollbackCannotReuseAnEarlierVersion() throws {
    let journal = InMemoryKeychain()
    let legacy = InMemoryKeychain()
    try legacy.set("7000", forKey: ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue)
    try legacy.set("8000", forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue)
    let store = ClerkIdentityStore(keychain: InMemoryKeychain(), instanceFingerprint: "instance", clearIntentKeychain: journal)
    let signedIn = WatchSyncState(deviceToken: "token", client: .mock, serverDate: nil)
    let first = try #require(try WatchSyncLegacyPublication.version(for: signedIn, store: store, legacyKeychain: legacy,
                                                                    now: Date(timeIntervalSince1970: 10)))
    let clear = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 1)
    let next = try #require(try WatchSyncLegacyPublication.version(for: clear, store: store, legacyKeychain: legacy,
                                                                   now: Date(timeIntervalSince1970: 1)))
    #expect(first > 8000)
    #expect(next > first)
    #expect(try WatchSyncLegacyPublication.version(for: clear, store: store, legacyKeychain: legacy,
                                                   now: Date(timeIntervalSince1970: 100)) == next)
  }

  @Test
  func exhaustedLegacyVersionsDoNotWrapAndOwnersDoNotSharePublicationState() throws {
    let journal = InMemoryKeychain()
    let first = ClerkIdentityStore(keychain: journal, instanceFingerprint: "instance", watchSyncOwnerIdentifier: "first")
    let sibling = ClerkIdentityStore(keychain: journal, instanceFingerprint: "instance", watchSyncOwnerIdentifier: "sibling")
    let legacy = InMemoryKeychain()
    let state = WatchSyncState(deviceToken: "token", client: .mock, serverDate: nil)
    _ = try WatchSyncLegacyPublication.version(for: state, store: first, legacyKeychain: legacy)
    try legacy.set(String(Int.max), forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue)
    #expect(throws: (any Error).self) { try WatchSyncLegacyPublication.version(for: state, store: sibling, legacyKeychain: legacy) }
  }

  @Test(arguments: [false, true])
  @MainActor
  func unreadableOrUnwritablePublicationDoesNotSendAndCanRetryAfterRestart(failsRead: Bool) throws {
    configureClerkForTesting()
    let journal = PublicationJournal()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(), appLocalKeychain: journal)
    try clerk.seedIdentity(deviceToken: "token", client: .mock)
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    coordinator.sync(from: clerk)
    let initial = try #require(transport.sent.last?.legacyVersion?.token)
    journal.failsRead = failsRead
    journal.failsWrite = !failsRead
    try clerk.clearKeychainItems()
    coordinator.sync(from: clerk)
    #expect(transport.sent.count == 1)
    #expect(clerk.deviceToken == nil)
    journal.failsRead = false
    journal.failsWrite = false
    clerk.identityController.prepareForConfiguration()
    clerk.identityController.hydrate()
    WatchConnectivityCoordinator(transport: transport).sync(from: clerk)
    #expect(transport.sent.count == 2)
    #expect(transport.sent.last?.state?.isCleared == true)
    #expect(try #require(transport.sent.last?.legacyVersion?.token) > initial)
  }
}

private final class PublicationJournal: KeychainStorage, @unchecked Sendable {
  private let backing = InMemoryKeychain()
  var failsRead = false
  var failsWrite = false
  var failsFloorWrite = false
  func data(forKey key: String) throws -> Data? {
    if failsRead, key.contains(".watchPublication.") { throw KeychainError.invalidStringEncoding }
    return try backing.data(forKey: key)
  }

  func set(_ data: Data, forKey key: String) throws {
    if failsWrite, key.contains(".watchPublication.") { throw KeychainError.invalidStringEncoding }
    if failsFloorWrite, key == ClerkKeychainKey.watchSyncAuthVersion.rawValue { throw KeychainError.invalidStringEncoding }
    try backing.set(data, forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try data(forKey: key) != nil
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }
}
