//
//  ClerkIdentityStore.swift
//  Clerk
//

import CryptoKit
import Foundation

/// Identifies one Clerk instance so identities for different instances never mix.
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
  /// The record belongs to another Clerk instance, for example after a publishable key change.
  case otherInstance
}

/// Persists Clerk's complete identity as a single Keychain item.
///
/// The device token, Client, and server date are written together, so a reader
/// can never observe a token paired with another identity's Client. When the
/// Keychain has an access group, every app and extension in that group reads and
/// writes the same item. A record written for another Clerk instance is ignored
/// and replaced by the next write.
struct ClerkIdentityStore {
  struct Record: Codable, Equatable {
    static let schemaVersion = 1

    let schemaVersion: Int
    /// Changes on every write, so a reader can tell whether another process wrote since it last looked.
    let revision: UUID
    let instanceFingerprint: String
    /// The bundle identifier of the app that wrote the record, when known.
    var writer: String?
    let identity: ClerkIdentitySnapshot
  }

  let keychain: any KeychainStorage
  let instanceFingerprint: String
  /// Recorded as the ``Record/writer`` of each save.
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

  /// Reads only the revision, so checking for another process's write skips decoding the Client.
  func revision() throws -> UUID? {
    struct Header: Decodable {
      let revision: UUID
    }
    guard let data = try keychain.data(forKey: key) else { return nil }
    return try JSONDecoder.clerkDecoder.decode(Header.self, from: data).revision
  }

  /// Saves `identity`, or deletes the item when the identity has no device token.
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
