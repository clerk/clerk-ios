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
  package let identifierHint: String?
  package let policy: TrustedDevicePolicy
  package let createdAt: Date
  package let updatedAt: Date

  private enum CodingKeys: String, CodingKey {
    case id
    case localKeyId
    case appIdentifier
    case identifierHint
    case policy
    case createdAt
    case updatedAt
  }

  package init(
    id: String,
    localKeyId: String,
    appIdentifier: String,
    identifierHint: String? = nil,
    policy: TrustedDevicePolicy = .biometryCurrentSet,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.localKeyId = localKeyId
    self.appIdentifier = appIdentifier
    self.identifierHint = Self.normalizedIdentifierHint(identifierHint)
    self.policy = policy
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  package init(
    trustedDevice: TrustedDevice,
    localKey: TrustedDeviceLocalKey,
    identifierHint: String? = nil
  ) {
    self.init(
      id: trustedDevice.id,
      localKeyId: localKey.localKeyId,
      appIdentifier: trustedDevice.appIdentifier,
      identifierHint: identifierHint,
      policy: localKey.policy,
      createdAt: trustedDevice.createdAt,
      updatedAt: trustedDevice.updatedAt
    )
  }

  package init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    localKeyId = try container.decode(String.self, forKey: .localKeyId)
    appIdentifier = try container.decode(String.self, forKey: .appIdentifier)
    identifierHint = try Self.normalizedIdentifierHint(container.decodeIfPresent(String.self, forKey: .identifierHint))
    policy = try container.decode(TrustedDevicePolicy.self, forKey: .policy)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  package func matches(identifierHint: String?) -> Bool {
    guard let normalizedIdentifierHint = Self.normalizedIdentifierHint(identifierHint) else {
      return true
    }
    return self.identifierHint == normalizedIdentifierHint
  }

  private static func normalizedIdentifierHint(_ identifierHint: String?) -> String? {
    guard let identifierHint else {
      return nil
    }
    let normalized = identifierHint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty ? nil : normalized
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
    var remainingCredentials: [TrustedDeviceLocalCredential] = []
    var keyDeletionError: Error?

    for credential in credentials {
      do {
        try keyManager.deleteKey(localKeyId: credential.localKeyId)
      } catch {
        remainingCredentials.append(credential)
        keyDeletionError = keyDeletionError ?? error
      }
    }

    if remainingCredentials.isEmpty {
      try deleteAll()
    } else if remainingCredentials.count < credentials.count {
      try persist(remainingCredentials)
    }

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
