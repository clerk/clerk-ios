//
//  SharedSessionSyncEnvelope.swift
//  Clerk
//

import CryptoKit
import Foundation

struct SharedSessionSyncNamespace: Equatable {
  let fingerprint: String

  init(frontendApiUrl: String) {
    fingerprint = Self.fingerprint(for: Self.normalize(frontendApiUrl))
  }

  private static func normalize(_ frontendApiUrl: String) -> String {
    var value = frontendApiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    while value.hasSuffix("/") {
      value.removeLast()
    }
    return value
  }

  static func fingerprint(for value: String) -> String {
    SHA256.hash(data: Data(value.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }
}

enum SharedSessionSyncEnvelopeState: String, Codable {
  case active
  case signedOut
}

struct SharedSessionSyncEnvelope: Codable, Equatable {
  static let schemaVersion = 1

  let schemaVersion: Int
  let instanceFingerprint: String
  let revision: UUID
  let state: SharedSessionSyncEnvelopeState
  let deviceToken: String?
  let client: Client?
  let serverDate: Date?
}

enum SharedSessionSyncEnvelopeError: Error, LocalizedError {
  case unsupportedSchemaVersion(Int)
  case instanceMismatch
  case invalidEnvelope

  var errorDescription: String? {
    switch self {
    case .unsupportedSchemaVersion(let version):
      "Unsupported shared session envelope schema version: \(version)."
    case .instanceMismatch:
      "The shared session envelope belongs to a different Clerk instance."
    case .invalidEnvelope:
      "The shared session envelope contains an invalid authentication state."
    }
  }
}

struct SharedSessionSyncStore {
  private let keychain: any KeychainStorage
  private let namespace: SharedSessionSyncNamespace

  init(
    keychain: any KeychainStorage,
    namespace: SharedSessionSyncNamespace
  ) {
    self.keychain = keychain
    self.namespace = namespace
  }

  var storageKey: String {
    "clerk.shared-session.envelope.v1.\(namespace.fingerprint)"
  }

  func load() throws -> SharedSessionSyncEnvelope? {
    guard let data = try keychain.data(forKey: storageKey) else {
      return nil
    }

    return try decode(data)
  }

  @discardableResult
  func save(
    deviceToken: String?,
    client: Client?,
    serverDate: Date?
  ) throws -> SharedSessionSyncEnvelope {
    let normalizedToken = deviceToken.nilIfEmpty
    if client != nil, normalizedToken == nil {
      throw SharedSessionSyncEnvelopeError.invalidEnvelope
    }

    let envelope = SharedSessionSyncEnvelope(
      schemaVersion: SharedSessionSyncEnvelope.schemaVersion,
      instanceFingerprint: namespace.fingerprint,
      revision: UUID(),
      state: client == nil ? .signedOut : .active,
      deviceToken: normalizedToken,
      client: client,
      serverDate: serverDate
    )
    try keychain.set(JSONEncoder.clerkEncoder.encode(envelope), forKey: storageKey)
    return envelope
  }

  func delete() throws {
    try keychain.deleteItem(forKey: storageKey)
  }

  private func decode(_ data: Data) throws -> SharedSessionSyncEnvelope {
    let envelope = try JSONDecoder.clerkDecoder.decode(SharedSessionSyncEnvelope.self, from: data)
    guard envelope.schemaVersion == SharedSessionSyncEnvelope.schemaVersion else {
      throw SharedSessionSyncEnvelopeError.unsupportedSchemaVersion(envelope.schemaVersion)
    }
    guard envelope.instanceFingerprint == namespace.fingerprint else {
      throw SharedSessionSyncEnvelopeError.instanceMismatch
    }

    switch envelope.state {
    case .active:
      guard envelope.client != nil, envelope.deviceToken.nilIfEmpty != nil else {
        throw SharedSessionSyncEnvelopeError.invalidEnvelope
      }
    case .signedOut:
      guard envelope.client == nil else {
        throw SharedSessionSyncEnvelopeError.invalidEnvelope
      }
    }

    return envelope
  }
}
