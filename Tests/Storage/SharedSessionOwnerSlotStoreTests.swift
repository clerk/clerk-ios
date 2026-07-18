@testable import ClerkKit
import Foundation
import Security
import Testing

@Suite(.serialized)
struct SharedSessionOwnerSlotStoreTests {
  private let namespace = SharedSessionNamespace(
    frontendApiUrl: "https://instance.example/",
    publishableKey: "pk_test_instance"
  )
  private let config = Clerk.Options.KeychainConfig(
    service: "com.example.clerk",
    accessGroup: "group.com.example"
  )

  @Test
  func matchAllQueryIsLimitedToV2ServiceAndAccessGroup() throws {
    let spy = SharedSessionSecItemSpy()
    spy.copyMatchingResults = [.status(errSecItemNotFound)]
    let store = try makeStore(owner: "app.a", spy: spy)

    #expect(try store.loadAllSlots().isEmpty)

    let query = try #require(spy.copyMatchingQueries.first)
    #expect(query[kSecClass as String] as? String == kSecClassGenericPassword as String)
    #expect(
      query[kSecAttrService as String] as? String
        == SharedSessionOwnerSlotStore.service(
          configuredService: config.service,
          instanceFingerprint: namespace.fingerprint
        )
    )
    #expect(query[kSecAttrAccessGroup as String] as? String == config.accessGroup)
    #expect(query[kSecAttrAccount as String] == nil)
    #expect(query[kSecMatchLimit as String] as? String == kSecMatchLimitAll as String)
    #expect(query[kSecReturnAttributes as String] as? Bool == true)
    #expect(query[kSecReturnData as String] as? Bool == true)
  }

  @Test
  func queriesUseNormalizedAccessGroup() throws {
    let spy = SharedSessionSecItemSpy()
    spy.copyMatchingResults = [.status(errSecItemNotFound)]
    let store = try SharedSessionOwnerSlotStore(
      keychainConfig: .init(
        service: config.service,
        accessGroup: "  group.com.example\n"
      ),
      namespace: namespace,
      ownerIdentifier: "app.a",
      secItemClient: spy.client,
      diagnostics: { _ in }
    )

    #expect(try store.loadAllSlots().isEmpty)

    let query = try #require(spy.copyMatchingQueries.first)
    #expect(query[kSecAttrAccessGroup as String] as? String == "group.com.example")
  }

  @Test
  func enumerationReturnsEveryCompatibleOwnerAndIgnoresInvalidPeers() throws {
    let spy = SharedSessionSecItemSpy()
    let first = makeSlot(owner: "app.a", generation: 1)
    let second = makeSlot(owner: "app.b", generation: 2)
    let futureData = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 3,
      "instanceFingerprint": namespace.fingerprint,
      "slotOwnerIdentifier": "app.future",
    ])
    let mismatchedAccount = SharedSessionOwnerSlotStore.account(
      instanceFingerprint: namespace.fingerprint,
      ownerIdentifier: "not.app.b"
    )
    spy.copyMatchingResults = try [.success([
      item(slot: first),
      item(slot: second),
      [
        kSecAttrAccount as String: SharedSessionOwnerSlotStore.account(
          instanceFingerprint: namespace.fingerprint,
          ownerIdentifier: "app.malformed"
        ),
        kSecValueData as String: Data("malformed".utf8),
      ],
      [
        kSecAttrAccount as String: SharedSessionOwnerSlotStore.account(
          instanceFingerprint: namespace.fingerprint,
          ownerIdentifier: "app.future"
        ),
        kSecValueData as String: futureData,
      ],
      [
        kSecAttrAccount as String: mismatchedAccount,
        kSecValueData as String: JSONEncoder.clerkEncoder.encode(second),
      ],
    ])]
    let store = try makeStore(owner: "app.a", spy: spy)

    let slots = try store.loadAllSlots()

    #expect(Set(slots.map(\.slotOwnerIdentifier)) == ["app.a", "app.b"])
  }

  @Test
  func enumerationIgnoresSameFrontendPeerFromDifferentPublishableKeyNamespace() throws {
    let oldNamespace = SharedSessionNamespace(
      frontendApiUrl: "https://instance.example/",
      publishableKey: "pk_test_old"
    )
    let newNamespace = SharedSessionNamespace(
      frontendApiUrl: "https://instance.example",
      publishableKey: "pk_live_new"
    )
    #expect(oldNamespace != newNamespace)

    let spy = SharedSessionSecItemSpy()
    let oldKeyPeer = makeSlot(owner: "app.old-key-peer", generation: 2, namespace: oldNamespace)
    let newKeyPeer = makeSlot(owner: "app.new-key-peer", generation: 1, namespace: newNamespace)
    spy.copyMatchingResults = [.success([
      item(slot: oldKeyPeer),
      item(slot: newKeyPeer),
    ])]
    let store = try makeStore(owner: "app.local", spy: spy, namespace: newNamespace)

    let slots = try store.loadAllSlots()

    #expect(slots.map(\.slotOwnerIdentifier) == ["app.new-key-peer"])
    let query = try #require(spy.copyMatchingQueries.first)
    #expect(
      query[kSecAttrService as String] as? String
        == SharedSessionOwnerSlotStore.service(
          configuredService: config.service,
          instanceFingerprint: newNamespace.fingerprint
        )
    )
  }

  @Test
  func saveWritesOnlyTheDerivedOwnAccount() throws {
    let spy = SharedSessionSecItemSpy()
    spy.copyMatchingResults = [.status(errSecItemNotFound)]
    let store = try makeStore(owner: "app.a", spy: spy)

    try store.saveOwnSlot(makeSlot(owner: "app.a", generation: 1))

    let query = try #require(spy.addQueries.first)
    #expect(
      query[kSecAttrAccount as String] as? String
        == SharedSessionOwnerSlotStore.account(
          instanceFingerprint: namespace.fingerprint,
          ownerIdentifier: "app.a"
        )
    )
  }

  @Test
  func saveUpdatesKnownExistingSlotWithoutTryingToAddIt() throws {
    let spy = SharedSessionSecItemSpy()
    let existing = makeSlot(owner: "app.a", generation: 1)
    spy.copyMatchingResults = try [
      .success(JSONEncoder.clerkEncoder.encode(existing)),
    ]
    let store = try makeStore(owner: "app.a", spy: spy)

    try store.saveOwnSlot(makeSlot(owner: "app.a", generation: 2))

    #expect(spy.updateQueries.count == 1)
    #expect(spy.addQueries.isEmpty)
  }

  @Test
  func saveAddsKnownSlotWhenItDisappearsBeforeUpdate() throws {
    let spy = SharedSessionSecItemSpy()
    let existing = makeSlot(owner: "app.a", generation: 1)
    spy.copyMatchingResults = try [
      .success(JSONEncoder.clerkEncoder.encode(existing)),
    ]
    spy.updateResults = [errSecItemNotFound]
    let store = try makeStore(owner: "app.a", spy: spy)

    try store.saveOwnSlot(makeSlot(owner: "app.a", generation: 2))

    #expect(spy.updateQueries.count == 1)
    #expect(spy.addQueries.count == 1)
  }

  @Test
  func addRaceDoesNotOverwriteFutureSchemaSlot() throws {
    let spy = SharedSessionSecItemSpy()
    let futureData = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 3,
      "renamedOwner": "future-app",
    ])
    spy.copyMatchingResults = [
      .status(errSecItemNotFound),
      .success(futureData),
    ]
    spy.addResults = [errSecDuplicateItem]
    let store = try makeStore(owner: "app.a", spy: spy)

    #expect(throws: SharedSessionOwnerSlotStoreError.futureSchemaVersion(3)) {
      try store.saveOwnSlot(makeSlot(owner: "app.a", generation: 2))
    }

    #expect(spy.updateQueries.isEmpty)
  }

  @Test
  func saveRejectsSlotForAnotherOwner() throws {
    let store = try makeStore(owner: "app.a", spy: SharedSessionSecItemSpy())

    #expect(throws: SharedSessionOwnerSlotStoreError.invalidOwnSlot) {
      try store.saveOwnSlot(makeSlot(owner: "app.b", generation: 1))
    }
  }

  @Test
  func deleteTargetsOnlyOwnAccount() throws {
    let spy = SharedSessionSecItemSpy()
    spy.copyMatchingResults = [.status(errSecItemNotFound)]
    let store = try makeStore(owner: "app.a", spy: spy)

    try store.deleteOwnSlot()

    let query = try #require(spy.deleteQueries.first)
    #expect(
      query[kSecAttrAccount as String] as? String
        == SharedSessionOwnerSlotStore.account(
          instanceFingerprint: namespace.fingerprint,
          ownerIdentifier: "app.a"
        )
    )
  }

  @Test
  func futureOwnSlotIsPreserved() throws {
    let spy = SharedSessionSecItemSpy()
    let futureData = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 3,
      "instanceFingerprint": namespace.fingerprint,
      "slotOwnerIdentifier": "app.a",
    ])
    spy.copyMatchingResults = [.success(futureData), .success(futureData)]
    let store = try makeStore(owner: "app.a", spy: spy)

    #expect(throws: SharedSessionOwnerSlotStoreError.futureSchemaVersion(3)) {
      try store.saveOwnSlot(makeSlot(owner: "app.a", generation: 1))
    }
    try store.deleteOwnSlot()

    #expect(spy.addQueries.isEmpty)
    #expect(spy.updateQueries.isEmpty)
    #expect(spy.deleteQueries.isEmpty)
  }

  @Test
  func futureOwnSlotIsPreservedWhenCurrentHeaderFieldsAreAbsent() throws {
    let spy = SharedSessionSecItemSpy()
    let futureData = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 3,
      "renamedOwner": "future-app",
    ])
    spy.copyMatchingResults = [.success(futureData), .success(futureData)]
    let store = try makeStore(owner: "app.a", spy: spy)

    #expect(throws: SharedSessionOwnerSlotStoreError.futureSchemaVersion(3)) {
      try store.saveOwnSlot(makeSlot(owner: "app.a", generation: 1))
    }
    try store.deleteOwnSlot()

    #expect(spy.addQueries.isEmpty)
    #expect(spy.updateQueries.isEmpty)
    #expect(spy.deleteQueries.isEmpty)
  }

  @Test
  func keychainReadFailureIsNotTreatedAsEmptyStorage() throws {
    let spy = SharedSessionSecItemSpy()
    spy.copyMatchingResults = [.status(errSecInteractionNotAllowed)]
    let store = try makeStore(owner: "app.a", spy: spy)

    #expect(throws: KeychainError.self) {
      _ = try store.loadAllSlots()
    }
  }

  private func makeStore(
    owner: String,
    spy: SharedSessionSecItemSpy,
    namespace: SharedSessionNamespace? = nil
  ) throws -> SharedSessionOwnerSlotStore {
    try SharedSessionOwnerSlotStore(
      keychainConfig: config,
      namespace: namespace ?? self.namespace,
      ownerIdentifier: owner,
      secItemClient: spy.client,
      diagnostics: { _ in }
    )
  }

  private func makeSlot(
    owner: String,
    generation: UInt64,
    namespace: SharedSessionNamespace? = nil
  ) -> SharedSessionOwnerSlot {
    let namespace = namespace ?? self.namespace
    return SharedSessionOwnerSlot(
      schemaVersion: SharedSessionOwnerSlot.schemaVersion,
      instanceFingerprint: namespace.fingerprint,
      slotOwnerIdentifier: owner,
      event: SharedSessionIdentityEvent(
        id: UUID(),
        originOwnerIdentifier: owner,
        generation: generation,
        state: .present,
        deviceToken: "token-\(owner)",
        client: .mock,
        serverDate: nil
      )
    )
  }

  private func item(slot: SharedSessionOwnerSlot) -> [String: Any] {
    [
      kSecAttrAccount as String: SharedSessionOwnerSlotStore.account(
        instanceFingerprint: slot.instanceFingerprint,
        ownerIdentifier: slot.slotOwnerIdentifier
      ),
      kSecValueData as String: try! JSONEncoder.clerkEncoder.encode(slot),
    ]
  }
}

private final class SharedSessionSecItemSpy: @unchecked Sendable {
  enum CopyMatchingResult {
    case success(Any)
    case status(OSStatus)
  }

  var addResults: [OSStatus] = []
  var updateResults: [OSStatus] = []
  var copyMatchingResults: [CopyMatchingResult] = []
  var deleteResults: [OSStatus] = []

  var addQueries: [[String: Any]] = []
  var updateQueries: [[String: Any]] = []
  var copyMatchingQueries: [[String: Any]] = []
  var deleteQueries: [[String: Any]] = []

  var client: SystemKeychain.SecItemClient {
    .init(
      add: { query, _ in
        self.addQueries.append(Self.dictionary(from: query))
        return self.addResults.isEmpty ? errSecSuccess : self.addResults.removeFirst()
      },
      update: { query, _ in
        self.updateQueries.append(Self.dictionary(from: query))
        return self.updateResults.isEmpty ? errSecSuccess : self.updateResults.removeFirst()
      },
      copyMatching: { query, result in
        self.copyMatchingQueries.append(Self.dictionary(from: query))
        guard !self.copyMatchingResults.isEmpty else {
          return errSecItemNotFound
        }
        switch self.copyMatchingResults.removeFirst() {
        case .success(let value):
          result?.pointee = value as CFTypeRef
          return errSecSuccess
        case .status(let status):
          return status
        }
      },
      delete: { query in
        self.deleteQueries.append(Self.dictionary(from: query))
        return self.deleteResults.isEmpty ? errSecSuccess : self.deleteResults.removeFirst()
      }
    )
  }

  private static func dictionary(from value: CFDictionary) -> [String: Any] {
    value as NSDictionary as? [String: Any] ?? [:]
  }
}
