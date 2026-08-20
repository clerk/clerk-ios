//
//  BiometricCredentialLocalCredentialStore.swift
//  Clerk
//

import Foundation

/// Local metadata that links a Clerk biometric credential to its on-device private key.
package struct BiometricCredentialLocalCredential: Codable, Equatable, Identifiable {
  package let id: String
  package let localKeyId: String
  package let userID: String
  package let appIdentifier: String
  package let identifierHint: String?
  package let policy: BiometricCredentialPolicy
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
    policy: BiometricCredentialPolicy = .biometryCurrentSet,
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
    biometricCredential: BiometricCredential,
    localKey: BiometricCredentialLocalKey,
    userID: String,
    identifierHint: String? = nil
  ) {
    self.init(
      id: biometricCredential.id,
      localKeyId: localKey.localKeyId,
      userID: userID,
      appIdentifier: biometricCredential.appIdentifier,
      identifierHint: identifierHint,
      policy: localKey.policy,
      createdAt: biometricCredential.createdAt,
      updatedAt: biometricCredential.updatedAt
    )
  }

  package init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    localKeyId = try container.decode(String.self, forKey: .localKeyId)
    userID = try container.decode(String.self, forKey: .userID)
    appIdentifier = try container.decode(String.self, forKey: .appIdentifier)
    identifierHint = try Self.normalizedIdentifierHint(container.decodeIfPresent(String.self, forKey: .identifierHint))
    policy = try container.decode(BiometricCredentialPolicy.self, forKey: .policy)
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

package protocol BiometricCredentialLocalCredentialStoreProtocol: Sendable {
  @MainActor func all() throws -> [BiometricCredentialLocalCredential]
  @MainActor func all(appIdentifier: String) throws -> [BiometricCredentialLocalCredential]
  @MainActor func credential(id: String) throws -> BiometricCredentialLocalCredential?
  @MainActor func save(
    _ credential: BiometricCredentialLocalCredential,
    deleteReplacedLocalKey: (String) throws -> Void
  ) throws
  @MainActor func delete(id: String) throws
  @MainActor func deleteAll() throws
  @MainActor func deleteLocalCredentials(
    appIdentifier: String,
    keyManager: any BiometricCredentialKeyManagerProtocol
  ) throws
  @MainActor func deleteAllLocalCredentials(keyManager: any BiometricCredentialKeyManagerProtocol) throws
}

extension BiometricCredentialLocalCredentialStoreProtocol {
  @MainActor
  func save(_ credential: BiometricCredentialLocalCredential) throws {
    try save(credential, deleteReplacedLocalKey: { _ in })
  }
}

final class BiometricCredentialLocalCredentialStore: BiometricCredentialLocalCredentialStoreProtocol {
  private let keychain: any KeychainStorage
  private let keychainKey = ClerkKeychainKey.biometricCredentials.rawValue

  init(keychain: any KeychainStorage) {
    self.keychain = keychain
  }

  @MainActor
  func all() throws -> [BiometricCredentialLocalCredential] {
    guard let data = try keychain.data(forKey: keychainKey) else {
      return []
    }
    return try Self.metadataDecoder().decode([BiometricCredentialLocalCredential].self, from: data)
  }

  @MainActor
  func all(appIdentifier: String) throws -> [BiometricCredentialLocalCredential] {
    var credentials: [BiometricCredentialLocalCredential] = []
    for record in try rawCredentialRecords() {
      guard record[BiometricCredentialLocalCredentialMetadataKey.appIdentifier] as? String == appIdentifier else {
        continue
      }
      guard let credential = try? Self.decodeCredentialRecord(record) else {
        continue
      }
      credentials.append(credential)
    }
    return credentials
  }

  @MainActor
  func credential(id: String) throws -> BiometricCredentialLocalCredential? {
    for record in try rawCredentialRecords() {
      guard record[BiometricCredentialLocalCredentialMetadataKey.id] as? String == id else {
        continue
      }
      return try Self.decodeCredentialRecord(record)
    }

    return nil
  }

  @MainActor
  func save(
    _ credential: BiometricCredentialLocalCredential,
    deleteReplacedLocalKey: (String) throws -> Void
  ) throws {
    let credentialRecord = try Self.rawCredentialRecord(for: credential)
    var records: [[String: Any]] = []
    var replacedLocalKeyIds: [String] = []

    for record in try rawCredentialRecords() {
      if record[BiometricCredentialLocalCredentialMetadataKey.id] as? String == credential.id {
        if let localKeyId = record[BiometricCredentialLocalCredentialMetadataKey.localKeyId] as? String,
           localKeyId != credential.localKeyId
        {
          replacedLocalKeyIds.append(localKeyId)
        }
        continue
      }
      guard record[BiometricCredentialLocalCredentialMetadataKey.appIdentifier] as? String == credential.appIdentifier else {
        records.append(record)
        continue
      }
      if (try? Self.decodeCredentialRecord(record)) != nil {
        records.append(record)
      }
    }

    records.append(credentialRecord)
    try persistRawRecords(records)

    for localKeyId in replacedLocalKeyIds {
      try? deleteReplacedLocalKey(localKeyId)
    }
  }

  @MainActor
  func delete(id: String) throws {
    try persistRawRecords(rawCredentialRecords().filter {
      $0[BiometricCredentialLocalCredentialMetadataKey.id] as? String != id
    })
  }

  @MainActor
  func deleteAll() throws {
    try keychain.deleteItem(forKey: keychainKey)
  }

  @MainActor
  func deleteAllLocalCredentials(keyManager: any BiometricCredentialKeyManagerProtocol) throws {
    try deleteLocalCredentials(keyManager: keyManager, shouldDelete: { _ in
      true
    })
  }

  @MainActor
  func deleteLocalCredentials(
    appIdentifier: String,
    keyManager: any BiometricCredentialKeyManagerProtocol
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
    keyManager: any BiometricCredentialKeyManagerProtocol,
    shouldDelete: (BiometricCredentialLocalCredential) -> Bool,
    deleteMalformedLocalCredentials: (() throws -> Void)? = nil
  ) throws {
    let credentials: [BiometricCredentialLocalCredential]
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

    var remainingCredentials = credentials
    var keyDeletionError: Error?

    for credential in credentials {
      guard shouldDelete(credential) else { continue }

      do {
        try keyManager.deleteKey(localKeyId: credential.localKeyId)
      } catch {
        keyDeletionError = keyDeletionError ?? error
        continue
      }

      remainingCredentials.removeAll { $0 == credential }
      try persist(remainingCredentials)
    }

    if let keyDeletionError {
      throw keyDeletionError
    }
  }

  @MainActor
  private func deleteMalformedLocalCredentials(
    appIdentifier: String,
    keyManager: any BiometricCredentialKeyManagerProtocol
  ) throws {
    guard let data = try keychain.data(forKey: keychainKey) else {
      return
    }

    let records = try rawCredentialRecords(from: data)

    var deletedRecordIndexes = Set<Int>()
    var keyDeletionError: Error?

    for (index, record) in records.enumerated() {
      guard record[BiometricCredentialLocalCredentialMetadataKey.appIdentifier] as? String == appIdentifier else {
        continue
      }

      guard let localKeyId = record[BiometricCredentialLocalCredentialMetadataKey.localKeyId] as? String else {
        deletedRecordIndexes.insert(index)
        try persistRawRecords(records, excludingIndexes: deletedRecordIndexes)
        continue
      }

      do {
        try keyManager.deleteKey(localKeyId: localKeyId)
      } catch {
        keyDeletionError = keyDeletionError ?? error
        continue
      }

      deletedRecordIndexes.insert(index)
      try persistRawRecords(records, excludingIndexes: deletedRecordIndexes)
    }

    if let keyDeletionError {
      throw keyDeletionError
    }
  }

  @MainActor
  private func deleteAllMalformedLocalCredentials(keyManager: any BiometricCredentialKeyManagerProtocol) throws {
    guard let data = try keychain.data(forKey: keychainKey) else {
      return
    }

    let records: [[String: Any]]
    do {
      records = try rawCredentialRecords(from: data)
    } catch {
      try deleteAll()
      return
    }

    var deletedRecordIndexes = Set<Int>()
    var keyDeletionError: Error?
    for (index, record) in records.enumerated() {
      guard let localKeyId = record[BiometricCredentialLocalCredentialMetadataKey.localKeyId] as? String else {
        deletedRecordIndexes.insert(index)
        try persistRawRecords(records, excludingIndexes: deletedRecordIndexes)
        continue
      }

      do {
        try keyManager.deleteKey(localKeyId: localKeyId)
      } catch {
        keyDeletionError = keyDeletionError ?? error
        continue
      }

      deletedRecordIndexes.insert(index)
      try persistRawRecords(records, excludingIndexes: deletedRecordIndexes)
    }

    if let keyDeletionError {
      throw keyDeletionError
    }

    try deleteAll()
  }

  @MainActor
  private func persist(_ credentials: [BiometricCredentialLocalCredential]) throws {
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
  private func persistRawRecords(
    _ records: [[String: Any]],
    excludingIndexes deletedRecordIndexes: Set<Int>
  ) throws {
    try persistRawRecords(records.enumerated().compactMap { index, record in
      deletedRecordIndexes.contains(index) ? nil : record
    })
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
        debugDescription: "Biometric-credential credential metadata is not an array."
      ))
    }
    return records
  }

  private static func decodeCredentialRecord(_ record: [String: Any]) throws -> BiometricCredentialLocalCredential {
    try metadataDecoder().decode(
      BiometricCredentialLocalCredential.self,
      from: JSONSerialization.data(withJSONObject: record)
    )
  }

  private static func rawCredentialRecord(for credential: BiometricCredentialLocalCredential) throws -> [String: Any] {
    let data = try metadataEncoder().encode(credential)
    guard let record = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw EncodingError.invalidValue(credential, .init(
        codingPath: [],
        debugDescription: "Biometric-credential credential metadata is not an object."
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

private enum BiometricCredentialLocalCredentialMetadataKey {
  static let id = "id"
  static let localKeyId = "localKeyId"
  static let appIdentifier = "appIdentifier"
}
