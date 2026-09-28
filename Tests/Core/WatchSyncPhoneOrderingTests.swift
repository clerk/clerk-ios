@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct WatchSyncPhoneOrderingTests {
  @Test
  func retainedHistoryUsesCommittedPhoneVersionsAndIsScopedToOwnerAndInstance() throws {
    let journal = InMemoryKeychain()
    let legacy = InMemoryKeychain()
    let first = ClerkIdentityStore(keychain: journal, instanceFingerprint: "instance", watchSyncOwnerIdentifier: "first")
    let sibling = ClerkIdentityStore(keychain: journal, instanceFingerprint: "instance", watchSyncOwnerIdentifier: "sibling")
    let otherInstance = ClerkIdentityStore(keychain: journal, instanceFingerprint: "other", watchSyncOwnerIdentifier: "first")
    let metadata = try JSONSerialization.data(withJSONObject: [
      "device_token_version": 100, "device_token_source": "phone",
      "auth_version": 200, "auth_source": "watch",
      "pending_auth_version": 500, "pending_auth_source": "phone",
    ])
    try legacy.set(metadata, forKey: ClerkKeychainKey.watchSyncMetadata.rawValue)
    try WatchSyncPhoneOrdering.preserveLegacy(in: legacy, store: first)
    #expect(try WatchSyncPhoneOrdering.loadPreservedLegacy(in: first)?.version == .init(token: 100, auth: nil))
    #expect(try WatchSyncPhoneOrdering.loadPreservedLegacy(in: sibling) == nil)
    #expect(try WatchSyncPhoneOrdering.loadPreservedLegacy(in: otherInstance) == nil)

    // Without the owner context, storage-only cleanup must retain the receive history.
    try Clerk.clearAllKeychainItemsStrictly(in: legacy)
    #expect(try legacy.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue) == metadata)
    try legacy.set(JSONSerialization.data(withJSONObject: [
      "device_token_version": 90, "device_token_source": "phone",
      "auth_version": 70, "auth_source": "phone",
    ]), forKey: ClerkKeychainKey.watchSyncMetadata.rawValue)
    try WatchSyncPhoneOrdering.preserveLegacy(in: legacy, store: first)
    try WatchSyncPhoneOrdering.preserveLegacy(in: legacy, store: sibling)
    #expect(try WatchSyncPhoneOrdering.loadPreservedLegacy(in: first)?.version == .init(token: 100, auth: 70))
    #expect(try WatchSyncPhoneOrdering.loadPreservedLegacy(in: sibling)?.version == .init(token: 90, auth: 70))
  }

  @Test(arguments: [false, true])
  func failedPreservationKeepsReceiveHistoryUntilCleanupCanRetry(failsRead: Bool) throws {
    let journal = PhoneOrderingJournal()
    let legacy = InMemoryKeychain()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope), keychain: legacy,
      appLocalKeychain: journal, identityKeychain: InMemoryKeychain()
    )
    try clerk.seedIdentity(deviceToken: "old-token", client: .mock)
    let metadata = try JSONSerialization.data(withJSONObject: [
      "device_token_version": 100, "device_token_source": "phone",
      "auth_version": 100, "auth_source": "phone",
    ])
    try legacy.set(metadata, forKey: ClerkKeychainKey.watchSyncMetadata.rawValue)
    journal.failsRead = failsRead
    journal.failsWrite = !failsRead
    #expect(throws: (any Error).self) { try clerk.clearKeychainItems() }
    #expect(clerk.deviceToken == nil)
    #expect(clerk.client == nil)
    #expect(try legacy.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue) == metadata)

    journal.failsRead = false
    journal.failsWrite = false
    try clerk.clearKeychainItems()
    #expect(try legacy.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue) == nil)
    try clerk.seedIdentity(deviceToken: "new-token", client: .mock)
    let restarted = Clerk()
    restarted.dependencies = clerk.dependencies
    restarted.identityController.hydrate()
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    for version in [99, 100, 101] {
      let payload = try #require(WatchSyncPayload(applicationContext: [
        "watchSyncDeviceTokenState": "cleared", "watchSyncDeviceTokenVersion": version,
        "watchSyncAuthState": "cleared", "watchSyncAuthVersion": version,
      ]))
      coordinator.apply(payload, from: .phone, to: restarted)
      #expect(restarted.deviceToken == (version > 100 ? nil : "new-token"))
    }
  }
}

private final class PhoneOrderingJournal: ForwardingTestKeychain, @unchecked Sendable {
  let backing = InMemoryKeychain()
  var failsRead = false
  var failsWrite = false

  func data(forKey key: String) throws -> Data? {
    if failsRead, key.contains(".legacyPhoneOrdering.") { throw KeychainError.invalidStringEncoding }
    return try backing.data(forKey: key)
  }

  func set(_ data: Data, forKey key: String) throws {
    if failsWrite, key.contains(".legacyPhoneOrdering.") { throw KeychainError.invalidStringEncoding }
    try backing.set(data, forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try data(forKey: key) != nil
  }
}
