//
//  ClerkIdentityStore.swift
//  Clerk
//

import CryptoKit
import Foundation

struct SharedSessionNamespace: Equatable {
  static let protocolIdentifier = "clerk.shared-session-sync.v2"

  let fingerprint: String

  init(frontendApiUrl: String, publishableKey: String) {
    var normalizedFrontendApiUrl = frontendApiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    while normalizedFrontendApiUrl.hasSuffix("/") {
      normalizedFrontendApiUrl.removeLast()
    }
    let normalizedPublishableKey = publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
    let seed = "\(Self.protocolIdentifier)\u{1F}\(normalizedFrontendApiUrl)\u{1F}\(normalizedPublishableKey)"
    fingerprint = Self.sha256(seed)
  }

  static func sha256(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }
}

enum ClerkIdentityStoreError: Error, Equatable {
  case unsupportedSchemaVersion(Int)
  case otherInstance
}

struct ClerkIdentityStore {
  struct Record: Codable, Equatable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let revision: UUID
    let instanceFingerprint: String
    var writer: String?
    let identity: ClerkIdentitySnapshot
  }

  let keychain: any KeychainStorage
  let instanceFingerprint: String
  var writer: String?
  let key = ClerkKeychainKey.identity.rawValue

  func load() throws -> Record? {
    guard let data = try keychain.data(forKey: key) else { return nil }
    let record = try JSONDecoder.clerkDecoder.decode(Record.self, from: data)
    guard record.schemaVersion == Record.schemaVersion else {
      throw ClerkIdentityStoreError.unsupportedSchemaVersion(record.schemaVersion)
    }
    guard record.instanceFingerprint == instanceFingerprint else {
      throw ClerkIdentityStoreError.otherInstance
    }
    _ = try record.identity.validated()
    return record
  }

  func revision() throws -> UUID? {
    struct Header: Decodable {
      let revision: UUID
    }
    guard let data = try keychain.data(forKey: key) else { return nil }
    return try JSONDecoder.clerkDecoder.decode(Header.self, from: data).revision
  }

  @discardableResult
  func save(_ identity: ClerkIdentitySnapshot) throws -> Record? {
    let identity = try identity.validated()
    guard identity.deviceToken != nil else {
      try delete()
      return nil
    }
    let record = Record(
      schemaVersion: Record.schemaVersion,
      revision: UUID(),
      instanceFingerprint: instanceFingerprint,
      writer: writer,
      identity: identity
    )
    try keychain.set(JSONEncoder.clerkEncoder.encode(record), forKey: key)
    return record
  }

  func delete() throws {
    try keychain.deleteItem(forKey: key)
  }
}
