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
    let credential = TrustedDeviceLocalCredential(
      trustedDevice: .mock,
      localKey: .mock
    )

    #expect(credential.id == TrustedDevice.mock.id)
    #expect(credential.localKeyId == TrustedDeviceLocalKey.mock.localKeyId)
    #expect(credential.appIdentifier == TrustedDevice.mock.appIdentifier)
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
