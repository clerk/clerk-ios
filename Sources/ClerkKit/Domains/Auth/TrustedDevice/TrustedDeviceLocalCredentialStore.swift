//
//  TrustedDeviceLocalCredentialStore.swift
//  Clerk
//

import Foundation

/// Local metadata that links a Clerk trusted-device credential to its on-device private key.
package struct TrustedDeviceLocalCredential: Codable, Equatable, Identifiable {
  package let id: String
  package let localKeyId: String
  package let userID: String
  package let appIdentifier: String
  package let identifierHint: String?
  package let policy: TrustedDevicePolicy
  package let createdAt: Date
  package let updatedAt: Date

  private enum CodingKeys: String, CodingKey {
    case id
    case localKeyId
    case userID = "userId"
    case appIdentifier
    case identifierHint
    case policy
    case createdAt
    case updatedAt
  }

  package init(
    id: String,
    localKeyId: String,
    userID: String,
    appIdentifier: String,
    identifierHint: String? = nil,
    policy: TrustedDevicePolicy = .biometryOrDevicePasscode,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.localKeyId = localKeyId
    self.userID = userID
    self.appIdentifier = appIdentifier
    self.identifierHint = Self.normalizedIdentifierHint(identifierHint)
    self.policy = policy
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  package init(
    trustedDevice: TrustedDevice,
    localKey: TrustedDeviceLocalKey,
    userID: String,
    identifierHint: String? = nil
  ) {
    self.init(
      id: trustedDevice.id,
      localKeyId: localKey.localKeyId,
      userID: userID,
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
    userID = try container.decode(String.self, forKey: .userID)
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
  @MainActor func all(appIdentifier: String) throws -> [TrustedDeviceLocalCredential]
  @MainActor func credential(id: String) throws -> TrustedDeviceLocalCredential?
  @MainActor func save(_ credential: TrustedDeviceLocalCredential) throws
  @MainActor func delete(id: String) throws
  @MainActor func deleteAll() throws
  @MainActor func deleteLocalCredentials(
    appIdentifier: String,
    keyManager: any TrustedDeviceKeyManagerProtocol
  ) throws
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
  func all(appIdentifier: String) throws -> [TrustedDeviceLocalCredential] {
    try rawCredentialRecords().compactMap { record in
      guard record[TrustedDeviceLocalCredentialMetadataKey.appIdentifier] as? String == appIdentifier else {
        return nil
      }
      return try Self.decodeCredentialRecord(record)
    }
  }

  @MainActor
  func credential(id: String) throws -> TrustedDeviceLocalCredential? {
    for record in try rawCredentialRecords() {
      guard record[TrustedDeviceLocalCredentialMetadataKey.id] as? String == id else {
        continue
      }
      return try Self.decodeCredentialRecord(record)
    }

    return nil
  }

  @MainActor
  func save(_ credential: TrustedDeviceLocalCredential) throws {
    let credentialRecord = try Self.rawCredentialRecord(for: credential)
    var records = try rawCredentialRecords().filter { record in
      guard record[TrustedDeviceLocalCredentialMetadataKey.id] as? String != credential.id else {
        return false
      }
      guard record[TrustedDeviceLocalCredentialMetadataKey.appIdentifier] as? String == credential.appIdentifier else {
        return true
      }
      return (try? Self.decodeCredentialRecord(record)) != nil
    }
    records.append(credentialRecord)
    try persistRawRecords(records)
  }

  @MainActor
  func delete(id: String) throws {
    try persistRawRecords(rawCredentialRecords().filter {
      $0[TrustedDeviceLocalCredentialMetadataKey.id] as? String != id
    })
  }

  @MainActor
  func deleteAll() throws {
    try keychain.deleteItem(forKey: keychainKey)
  }

  @MainActor
  func deleteAllLocalCredentials(keyManager: any TrustedDeviceKeyManagerProtocol) throws {
    try deleteLocalCredentials(keyManager: keyManager, shouldDelete: { _ in
      true
    })
  }

  @MainActor
  func deleteLocalCredentials(
    appIdentifier: String,
    keyManager: any TrustedDeviceKeyManagerProtocol
  ) throws {
    try deleteLocalCredentials(
      keyManager: keyManager,
      shouldDelete: { $0.appIdentifier == appIdentifier },
      deleteMalformedLocalCredentials: {
        try self.deleteMalformedLocalCredentials(appIdentifier: appIdentifier, keyManager: keyManager)
      }
    )
  }

  @MainActor
  private func deleteLocalCredentials(
    keyManager: any TrustedDeviceKeyManagerProtocol,
    shouldDelete: (TrustedDeviceLocalCredential) -> Bool,
    deleteMalformedLocalCredentials: (() throws -> Void)? = nil
  ) throws {
    let credentials: [TrustedDeviceLocalCredential]
    do {
      credentials = try all()
    } catch _ as DecodingError {
      if let deleteMalformedLocalCredentials {
        try deleteMalformedLocalCredentials()
      } else {
        try deleteAllMalformedLocalCredentials(keyManager: keyManager)
      }
      return
    }

    var remainingCredentials: [TrustedDeviceLocalCredential] = []
    var keyDeletionError: Error?

    for credential in credentials {
      guard shouldDelete(credential) else {
        remainingCredentials.append(credential)
        continue
      }

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
  private func deleteMalformedLocalCredentials(
    appIdentifier: String,
    keyManager: any TrustedDeviceKeyManagerProtocol
  ) throws {
    guard let data = try keychain.data(forKey: keychainKey) else {
      return
    }

    let records = try rawCredentialRecords(from: data)

    var remainingRecords: [[String: Any]] = []
    var deletedRecordCount = 0
    var keyDeletionError: Error?

    for record in records {
      guard record[TrustedDeviceLocalCredentialMetadataKey.appIdentifier] as? String == appIdentifier else {
        remainingRecords.append(record)
        continue
      }

      guard let localKeyId = record[TrustedDeviceLocalCredentialMetadataKey.localKeyId] as? String else {
        deletedRecordCount += 1
        continue
      }

      do {
        try keyManager.deleteKey(localKeyId: localKeyId)
        deletedRecordCount += 1
      } catch {
        remainingRecords.append(record)
        keyDeletionError = keyDeletionError ?? error
      }
    }

    if deletedRecordCount > 0 {
      try persistRawRecords(remainingRecords)
    }

    if let keyDeletionError {
      throw keyDeletionError
    }
  }

  @MainActor
  private func deleteAllMalformedLocalCredentials(keyManager: any TrustedDeviceKeyManagerProtocol) throws {
    guard let data = try keychain.data(forKey: keychainKey) else {
      return
    }

    let deletionRecords: [TrustedDeviceLocalCredentialDeletionRecord]
    do {
      deletionRecords = try Self.metadataDecoder().decode(
        [TrustedDeviceLocalCredentialDeletionRecord].self,
        from: data
      )
    } catch {
      try deleteAll()
      return
    }

    var keyDeletionError: Error?
    for record in deletionRecords {
      do {
        try keyManager.deleteKey(localKeyId: record.localKeyId)
      } catch {
        keyDeletionError = keyDeletionError ?? error
      }
    }

    if let keyDeletionError {
      throw keyDeletionError
    }

    try deleteAll()
  }

  @MainActor
  private func persist(_ credentials: [TrustedDeviceLocalCredential]) throws {
    if credentials.isEmpty {
      try deleteAll()
      return
    }

    try keychain.set(Self.metadataEncoder().encode(credentials), forKey: keychainKey)
  }

  @MainActor
  private func persistRawRecords(_ records: [[String: Any]]) throws {
    if records.isEmpty {
      try deleteAll()
      return
    }

    try keychain.set(JSONSerialization.data(withJSONObject: records), forKey: keychainKey)
  }

  @MainActor
  private func rawCredentialRecords() throws -> [[String: Any]] {
    guard let data = try keychain.data(forKey: keychainKey) else {
      return []
    }

    return try rawCredentialRecords(from: data)
  }

  private func rawCredentialRecords(from data: Data) throws -> [[String: Any]] {
    guard let records = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      throw DecodingError.dataCorrupted(.init(
        codingPath: [],
        debugDescription: "Trusted-device credential metadata is not an array."
      ))
    }
    return records
  }

  private static func decodeCredentialRecord(_ record: [String: Any]) throws -> TrustedDeviceLocalCredential {
    try metadataDecoder().decode(
      TrustedDeviceLocalCredential.self,
      from: JSONSerialization.data(withJSONObject: record)
    )
  }

  private static func rawCredentialRecord(for credential: TrustedDeviceLocalCredential) throws -> [String: Any] {
    let data = try metadataEncoder().encode(credential)
    guard let record = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw EncodingError.invalidValue(credential, .init(
        codingPath: [],
        debugDescription: "Trusted-device credential metadata is not an object."
      ))
    }
    return record
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

private struct TrustedDeviceLocalCredentialDeletionRecord: Decodable {
  enum CodingKeys: String, CodingKey {
    case localKeyId
    case appIdentifier
  }

  let localKeyId: String
  let appIdentifier: String?
}

private enum TrustedDeviceLocalCredentialMetadataKey {
  static let id = "id"
  static let localKeyId = "localKeyId"
  static let appIdentifier = "appIdentifier"
}
