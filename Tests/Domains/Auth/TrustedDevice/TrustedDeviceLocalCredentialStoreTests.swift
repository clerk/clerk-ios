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
      appIdentifier: "com.clerk.example",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 2)
    )

    try store.save(.mock)
    try store.save(updated)

    #expect(try store.all() == [updated])
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
      identifierHint: "  Sean@Example.COM  "
    )

    #expect(credential.id == TrustedDevice.mock.id)
    #expect(credential.localKeyId == TrustedDeviceLocalKey.mock.localKeyId)
    #expect(credential.appIdentifier == TrustedDevice.mock.appIdentifier)
    #expect(credential.identifierHint == "sean@example.com")
    #expect(credential.policy == .biometryOrDevicePasscode)
  }

  @Test
  func emptyIdentifierHintIsNotPersisted() {
    let credential = TrustedDeviceLocalCredential(
      id: "tdc_123",
      localKeyId: "tdlk_mock",
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
  func deleteAllLocalCredentialsDeletesKeysAndMetadata() throws {
    let store = TrustedDeviceLocalCredentialStore(keychain: InMemoryKeychain())
    let other = TrustedDeviceLocalCredential(
      id: "tdc_456",
      localKeyId: "tdlk_other",
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
