//
//  TrustedDeviceLocalCredentialStore.swift
//  Clerk
//

import Foundation

/// Local metadata that links a Clerk trusted-device credential to its on-device private key.
package struct TrustedDeviceLocalCredential: Codable, Equatable, Identifiable {
  package let id: String
  package let localKeyId: String
  package let appIdentifier: String
  package let createdAt: Date
  package let updatedAt: Date

  package init(
    id: String,
    localKeyId: String,
    appIdentifier: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.localKeyId = localKeyId
    self.appIdentifier = appIdentifier
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  package init(trustedDevice: TrustedDevice, localKey: TrustedDeviceLocalKey) {
    self.init(
      id: trustedDevice.id,
      localKeyId: localKey.localKeyId,
      appIdentifier: trustedDevice.appIdentifier,
      createdAt: trustedDevice.createdAt,
      updatedAt: trustedDevice.updatedAt
    )
  }
}

package protocol TrustedDeviceLocalCredentialStoreProtocol: Sendable {
  @MainActor func all() throws -> [TrustedDeviceLocalCredential]
  @MainActor func credential(id: String) throws -> TrustedDeviceLocalCredential?
  @MainActor func save(_ credential: TrustedDeviceLocalCredential) throws
  @MainActor func delete(id: String) throws
  @MainActor func deleteAll() throws
  @MainActor func deleteAllLocalCredentials(keyManager: any TrustedDeviceKeyManagerProtocol) throws
}

final class TrustedDeviceLocalCredentialStore: TrustedDeviceLocalCredentialStoreProtocol {
  private let keychain: any KeychainStorage
  private let keychainKey = ClerkKeychainKey.trustedDeviceCredentials.rawValue

  init(keychain: any KeychainStorage) {
    self.keychain = keychain
  }

  @MainActor
  func all() throws -> [TrustedDeviceLocalCredential] {
    guard let data = try keychain.data(forKey: keychainKey) else {
      return []
    }
    return try Self.metadataDecoder().decode([TrustedDeviceLocalCredential].self, from: data)
  }

  @MainActor
  func credential(id: String) throws -> TrustedDeviceLocalCredential? {
    try all().first { $0.id == id }
  }

  @MainActor
  func save(_ credential: TrustedDeviceLocalCredential) throws {
    var credentials = try all().filter { $0.id != credential.id }
    credentials.append(credential)
    try persist(credentials)
  }

  @MainActor
  func delete(id: String) throws {
    try persist(all().filter { $0.id != id })
  }

  @MainActor
  func deleteAll() throws {
    try keychain.deleteItem(forKey: keychainKey)
  }

  @MainActor
  func deleteAllLocalCredentials(keyManager: any TrustedDeviceKeyManagerProtocol) throws {
    let credentials = try all()
    var keyDeletionError: Error?

    for credential in credentials {
      do {
        try keyManager.deleteKey(localKeyId: credential.localKeyId)
      } catch {
        keyDeletionError = keyDeletionError ?? error
      }
    }

    try deleteAll()

    if let keyDeletionError {
      throw keyDeletionError
    }
  }

  @MainActor
  private func persist(_ credentials: [TrustedDeviceLocalCredential]) throws {
    if credentials.isEmpty {
      try deleteAll()
      return
    }

    try keychain.set(Self.metadataEncoder().encode(credentials), forKey: keychainKey)
  }

  private static func metadataEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    return encoder
  }

  private static func metadataDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    return decoder
  }
}
