@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct TrustedDeviceLocalCredentialStoreTests {
  @Test
  func saveAndLoadCredentialMetadata() throws {
    let store = TrustedDeviceLocalCredentialStore(keychain: InMemoryKeychain())

    try store.save(.mock)

    #expect(try store.all() == [.mock])
    #expect(try store.credential(id: "tdc_123") == .mock)
  }

  @Test
  func saveReplacesExistingCredentialMetadata() throws {
    let store = TrustedDeviceLocalCredentialStore(keychain: InMemoryKeychain())
    let updated = TrustedDeviceLocalCredential(
      id: "tdc_123",
      localKeyId: "tdlk_new",
      userID: User.mock.id,
      appIdentifier: "com.clerk.example",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 2)
    )

    try store.save(.mock)
    try store.save(updated)

    #expect(try store.all() == [updated])
  }

  @Test
  func saveDeletesReplacedLocalKeyAfterOverwritingMetadata() throws {
    let store = TrustedDeviceLocalCredentialStore(keychain: InMemoryKeychain())
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let updated = TrustedDeviceLocalCredential(
      id: "tdc_123",
      localKeyId: "tdlk_new",
      userID: User.mock.id,
      appIdentifier: "com.clerk.example",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 2)
    )

    try store.save(.mock)
    try store.save(updated, deleteReplacedLocalKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
    })

    #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
    #expect(try store.all() == [updated])
  }

  @Test
  func saveKeepsUpdatedMetadataWhenReplacedKeyDeletionFails() throws {
    let store = TrustedDeviceLocalCredentialStore(keychain: InMemoryKeychain())
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let updated = TrustedDeviceLocalCredential(
      id: "tdc_123",
      localKeyId: "tdlk_new",
      userID: User.mock.id,
      appIdentifier: "com.clerk.example",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 2)
    )

    try store.save(.mock)

    try store.save(updated, deleteReplacedLocalKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      throw TestKeyDeletionError.failed
    })

    #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
    #expect(try store.all() == [updated])
  }

  @Test
  func saveKeepsExistingMetadataAndKeyWhenReplacementPersistenceFails() throws {
    let keychain = WriteFailingKeychain(failStartingAtSet: 1)
    let store = TrustedDeviceLocalCredentialStore(keychain: keychain)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let updated = TrustedDeviceLocalCredential(
      id: "tdc_123",
      localKeyId: "tdlk_new",
      userID: User.mock.id,
      appIdentifier: "com.clerk.example",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 2)
    )

    try store.save(.mock)

    #expect(throws: WriteFailingKeychain.Failure.self) {
      try store.save(updated, deleteReplacedLocalKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    }

    #expect(deletedLocalKeyIds.value.isEmpty)
    #expect(try store.all() == [.mock])
  }

  @Test
  func deleteCredentialMetadata() throws {
    let store = TrustedDeviceLocalCredentialStore(keychain: InMemoryKeychain())

    try store.save(.mock)
    try store.delete(id: "tdc_123")

    #expect(try store.all().isEmpty)
    #expect(try store.credential(id: "tdc_123") == nil)
  }

  @Test
  func localCredentialCanBeBuiltFromServerCredentialAndLocalKey() {
    let localKey = TrustedDeviceLocalKey(
      localKeyId: TrustedDeviceLocalKey.mock.localKeyId,
      publicKeyJWK: TrustedDeviceLocalKey.mock.publicKeyJWK,
      policy: .biometryOrDevicePasscode
    )
    let credential = TrustedDeviceLocalCredential(
      trustedDevice: .mock,
      localKey: localKey,
      userID: User.mock.id,
      identifierHint: "  Sean@Example.COM  "
    )

    #expect(credential.id == TrustedDevice.mock.id)
    #expect(credential.localKeyId == TrustedDeviceLocalKey.mock.localKeyId)
    #expect(credential.userID == User.mock.id)
    #expect(credential.appIdentifier == TrustedDevice.mock.appIdentifier)
    #expect(credential.identifierHint == "sean@example.com")
    #expect(credential.policy == .biometryOrDevicePasscode)
  }

  @Test
  func emptyIdentifierHintIsNotPersisted() {
    let credential = TrustedDeviceLocalCredential(
      id: "tdc_123",
      localKeyId: "tdlk_mock",
      userID: User.mock.id,
      appIdentifier: "com.clerk.example",
      identifierHint: "   ",
      createdAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )

    #expect(credential.identifierHint == nil)
    #expect(credential.matches(identifierHint: nil))
    #expect(!credential.matches(identifierHint: "sean@example.com"))
  }

  @Test
  func credentialMetadataRequiresPolicy() throws {
    let keychain = InMemoryKeychain()
    try keychain.set(
      Data(
        """
        [{
          "id": "tdc_123",
          "localKeyId": "tdlk_mock",
          "userId": "1",
          "appIdentifier": "com.clerk.example",
          "createdAt": 1234567890000,
          "updatedAt": 1234567890000
        }]
        """.utf8
      ),
      forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue
    )
    let store = TrustedDeviceLocalCredentialStore(keychain: keychain)

    #expect(throws: DecodingError.self) {
      _ = try store.credential(id: "tdc_123")
    }
  }

  @Test
  func credentialMetadataRequiresUserID() throws {
    let keychain = InMemoryKeychain()
    try keychain.set(
      Data(
        """
        [{
          "id": "tdc_123",
          "localKeyId": "tdlk_mock",
          "appIdentifier": "com.clerk.example",
          "policy": "biometry_current_set",
          "createdAt": 1234567890000,
          "updatedAt": 1234567890000
        }]
        """.utf8
      ),
      forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue
    )
    let store = TrustedDeviceLocalCredentialStore(keychain: keychain)

    #expect(throws: DecodingError.self) {
      _ = try store.credential(id: "tdc_123")
    }
  }

  @Test
  func deleteAllLocalCredentialsDeletesKeysAndMetadata() throws {
    let store = TrustedDeviceLocalCredentialStore(keychain: InMemoryKeychain())
    let other = TrustedDeviceLocalCredential(
      id: "tdc_456",
      localKeyId: "tdlk_other",
      userID: User.mock.id,
      appIdentifier: "com.clerk.example",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 2)
    )
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let keyManager = MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
    })

    try store.save(.mock)
    try store.save(other)
    try store.deleteAllLocalCredentials(keyManager: keyManager)

    #expect(deletedLocalKeyIds.value == ["tdlk_mock", "tdlk_other"])
    #expect(try store.all().isEmpty)
  }

  @Test
  func deleteAllLocalCredentialsPreservesMetadataForFailedKeyDeletions() throws {
    let store = TrustedDeviceLocalCredentialStore(keychain: InMemoryKeychain())
    let failedCredential = TrustedDeviceLocalCredential(
      id: "tdc_failed",
      localKeyId: "tdlk_failed",
      userID: User.mock.id,
      appIdentifier: "com.clerk.example",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 2)
    )
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let keyManager = MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      if localKeyId == failedCredential.localKeyId {
        throw TestKeyDeletionError.failed
      }
    })

    try store.save(.mock)
    try store.save(failedCredential)

    #expect(throws: TestKeyDeletionError.self) {
      try store.deleteAllLocalCredentials(keyManager: keyManager)
    }

    #expect(deletedLocalKeyIds.value == ["tdlk_mock", "tdlk_failed"])
    #expect(try store.all() == [failedCredential])
  }

  @Test
  func deleteAllLocalCredentialsStopsAfterMetadataPersistenceFails() throws {
    let keychain = WriteFailingKeychain(failStartingAtSet: 2)
    let store = TrustedDeviceLocalCredentialStore(keychain: keychain)
    let other = TrustedDeviceLocalCredential(
      id: "tdc_456",
      localKeyId: "tdlk_other",
      userID: User.mock.id,
      appIdentifier: "com.clerk.example",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 2)
    )
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let keyManager = MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
    })

    try store.save(.mock)
    try store.save(other)

    #expect(throws: WriteFailingKeychain.Failure.self) {
      try store.deleteAllLocalCredentials(keyManager: keyManager)
    }

    #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
    #expect(try store.all() == [.mock, other])
  }

  @Test
  func deleteLocalCredentialsDeletesOnlyMatchingAppIdentifier() throws {
    let store = TrustedDeviceLocalCredentialStore(keychain: InMemoryKeychain())
    let otherAppCredential = TrustedDeviceLocalCredential(
      id: "tdc_other_app",
      localKeyId: "tdlk_other_app",
      userID: User.mock.id,
      appIdentifier: "com.clerk.other",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 2)
    )
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let keyManager = MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
    })

    try store.save(.mock)
    try store.save(otherAppCredential)
    try store.deleteLocalCredentials(
      appIdentifier: "com.clerk.example",
      keyManager: keyManager
    )

    #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
    #expect(try store.all() == [otherAppCredential])
  }

  @Test
  func appScopedReadsAndSavesIgnoreMalformedCredentialsForOtherApps() throws {
    let keychain = InMemoryKeychain()
    try keychain.set(
      Data(
        """
        [{
          "id": "tdc_other_app",
          "localKeyId": "tdlk_other_app",
          "appIdentifier": "com.clerk.other",
          "createdAt": 1234567890000,
          "updatedAt": 1234567890000
        }]
        """.utf8
      ),
      forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue
    )
    let store = TrustedDeviceLocalCredentialStore(keychain: keychain)

    try store.save(.mock)

    #expect(try store.all(appIdentifier: "com.clerk.example") == [.mock])
    #expect(try store.credential(id: TrustedDeviceLocalCredential.mock.id) == .mock)
    #expect(throws: DecodingError.self) {
      _ = try store.all()
    }
  }

  @Test
  func appScopedReadsSkipMalformedCredentialsForCurrentApp() throws {
    let keychain = InMemoryKeychain()
    try keychain.set(
      Data(
        """
        [
          {
            "id": "tdc_malformed",
            "localKeyId": "tdlk_malformed",
            "userId": "user_malformed",
            "appIdentifier": "com.clerk.example",
            "createdAt": 1234567890000,
            "updatedAt": 1234567890000
          },
          {
            "id": "tdc_valid",
            "localKeyId": "tdlk_valid",
            "userId": "user_valid",
            "appIdentifier": "com.clerk.example",
            "policy": "biometry_or_device_passcode",
            "createdAt": 1234567890000,
            "updatedAt": 1234567890000
          }
        ]
        """.utf8
      ),
      forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue
    )
    let store = TrustedDeviceLocalCredentialStore(keychain: keychain)

    let credentials = try store.all(appIdentifier: "com.clerk.example")

    #expect(credentials == [
      TrustedDeviceLocalCredential(
        id: "tdc_valid",
        localKeyId: "tdlk_valid",
        userID: "user_valid",
        appIdentifier: "com.clerk.example",
        createdAt: Date(timeIntervalSince1970: 1_234_567_890),
        updatedAt: Date(timeIntervalSince1970: 1_234_567_890)
      ),
    ])
    #expect(throws: DecodingError.self) {
      _ = try store.all()
    }
  }

  @Test
  func deleteAllLocalCredentialsDeletesMalformedMetadataAfterDeletingKeys() throws {
    let keychain = InMemoryKeychain()
    try keychain.set(
      Data(
        """
        [{
          "id": "tdc_legacy",
          "localKeyId": "tdlk_legacy",
          "appIdentifier": "com.clerk.example",
          "createdAt": 1234567890000,
          "updatedAt": 1234567890000
        }]
        """.utf8
      ),
      forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue
    )
    let store = TrustedDeviceLocalCredentialStore(keychain: keychain)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let keyManager = MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
    })

    try store.deleteAllLocalCredentials(keyManager: keyManager)

    #expect(deletedLocalKeyIds.value == ["tdlk_legacy"])
    #expect(try store.all().isEmpty)
  }

  @Test
  func deleteAllLocalCredentialsDeletesRecoverableKeysFromPartiallyMalformedMetadata() throws {
    let keychain = InMemoryKeychain()
    try keychain.set(
      Data(
        """
        [
          {
            "id": "tdc_recoverable",
            "localKeyId": "tdlk_recoverable",
            "appIdentifier": "com.clerk.example",
            "createdAt": 1234567890000,
            "updatedAt": 1234567890000
          },
          {
            "id": "tdc_without_local_key",
            "appIdentifier": "com.clerk.example",
            "createdAt": 1234567890000,
            "updatedAt": 1234567890000
          },
          {
            "id": "tdc_other",
            "localKeyId": "tdlk_other",
            "appIdentifier": "com.clerk.example",
            "createdAt": 1234567890000,
            "updatedAt": 1234567890000
          }
        ]
        """.utf8
      ),
      forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue
    )
    let store = TrustedDeviceLocalCredentialStore(keychain: keychain)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let keyManager = MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
    })

    try store.deleteAllLocalCredentials(keyManager: keyManager)

    #expect(deletedLocalKeyIds.value == ["tdlk_recoverable", "tdlk_other"])
    #expect(try store.all().isEmpty)
  }

  @Test
  func deleteAllLocalCredentialsPreservesMalformedMetadataForFailedKeyDeletions() throws {
    let metadata = Data(
      """
      [{
        "id": "tdc_legacy",
        "localKeyId": "tdlk_legacy",
        "appIdentifier": "com.clerk.example",
        "createdAt": 1234567890000,
        "updatedAt": 1234567890000
      }]
      """.utf8
    )
    let keychain = InMemoryKeychain()
    try keychain.set(metadata, forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue)
    let store = TrustedDeviceLocalCredentialStore(keychain: keychain)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let keyManager = MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      throw TestKeyDeletionError.failed
    })

    #expect(throws: TestKeyDeletionError.self) {
      try store.deleteAllLocalCredentials(keyManager: keyManager)
    }

    #expect(deletedLocalKeyIds.value == ["tdlk_legacy"])
    #expect(try keychain.data(forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue) == metadata)
  }

  @Test
  func deleteLocalCredentialsDeletesOnlyMatchingAppIdentifierFromMalformedMetadata() throws {
    let keychain = InMemoryKeychain()
    try keychain.set(
      Data(
        """
        [
          {
            "id": "tdc_current_app",
            "localKeyId": "tdlk_current_app",
            "appIdentifier": "com.clerk.example",
            "createdAt": 1234567890000,
            "updatedAt": 1234567890000
          },
          {
            "id": "tdc_other_app",
            "localKeyId": "tdlk_other_app",
            "appIdentifier": "com.clerk.other",
            "createdAt": 1234567890000,
            "updatedAt": 1234567890000
          }
        ]
        """.utf8
      ),
      forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue
    )
    let store = TrustedDeviceLocalCredentialStore(keychain: keychain)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let keyManager = MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
    })

    try store.deleteLocalCredentials(
      appIdentifier: "com.clerk.example",
      keyManager: keyManager
    )

    let remainingData = try #require(try keychain.data(forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue))
    let remainingObject = try JSONSerialization.jsonObject(with: remainingData)
    let remainingRecords = try #require(remainingObject as? [[String: Any]])
    let remainingRecord = try #require(remainingRecords.first)

    #expect(deletedLocalKeyIds.value == ["tdlk_current_app"])
    #expect(try store.all(appIdentifier: "com.clerk.example").isEmpty)
    #expect(remainingRecords.count == 1)
    #expect(remainingRecord["localKeyId"] as? String == "tdlk_other_app")
    #expect(remainingRecord["appIdentifier"] as? String == "com.clerk.other")
  }

  @Test
  func corruptCredentialMetadataThrows() throws {
    let keychain = InMemoryKeychain()
    try keychain.set(Data("not-json".utf8), forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue)
    let store = TrustedDeviceLocalCredentialStore(keychain: keychain)

    do {
      _ = try store.all()
      Issue.record("Expected corrupt metadata to throw.")
    } catch {
      #expect(error is DecodingError)
    }
  }
}

private enum TestKeyDeletionError: Error {
  case failed
}

private final class WriteFailingKeychain: @unchecked Sendable, KeychainStorage {
  enum Failure: Error {
    case set
  }

  private let lock = NSLock()
  private let failStartingAtSet: Int
  private var items: [String: Data] = [:]
  private var setCount = 0

  init(failStartingAtSet: Int) {
    self.failStartingAtSet = failStartingAtSet
  }

  func set(_ data: Data, forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    guard setCount < failStartingAtSet else {
      throw Failure.set
    }
    setCount += 1
    items[key] = data
  }

  func data(forKey key: String) throws -> Data? {
    lock.lock()
    defer { lock.unlock() }
    return items[key]
  }

  func deleteItem(forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    items.removeValue(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return items[key] != nil
  }
}
