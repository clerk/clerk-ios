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

enum ClerkIdentityStoreError: Error, Equatable, LocalizedError {
  case unsupportedSchemaVersion(Int)
  /// The record belongs to another Clerk instance, for example after a publishable key change.
  case otherInstance
  case writeConflict
  case clearPending

  var errorDescription: String? {
    switch self {
    case .unsupportedSchemaVersion:
      "The saved Clerk identity was written by an unsupported SDK version."
    case .otherInstance:
      "The saved identity belongs to another Clerk instance."
    case .writeConflict:
      "The shared sign-in state changed while this update was being saved. Try again."
    case .clearPending:
      "Clerk credentials could not be cleared. Retry the clear before making requests."
    }
  }
}

/// Persists Clerk's complete identity as a single Keychain item.
///
/// The device token, Client, and server date are written together, so a reader
/// can never observe a token paired with another identity's Client. When the
/// Keychain has an access group, every app and extension in that group reads and
/// writes the same item for that Clerk instance. Different instances use different accounts.
struct ClerkIdentityStore {
  /// Initialization can fail before first unlock. Retry it before hydration,
  /// rather than treating unavailable legacy credentials as a fresh install.
  final class Preparation: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private let operation: @Sendable () throws -> Void

    init(_ operation: @escaping @Sendable () throws -> Void) {
      self.operation = operation
    }

    func run() throws {
      try lock.withLock {
        guard !completed else { return }
        try operation()
        completed = true
      }
    }
  }

  struct Record: Codable, Equatable {
    static let schemaVersion = 2

    let schemaVersion: Int
    /// Changes on every write, so a reader can tell whether another process wrote since it last looked.
    let revision: UUID
    let instanceFingerprint: String
    let identity: ClerkIdentitySnapshot
    /// Changes on clear or token replacement, including when a previous token is reused.
    var epoch: UUID = .init()
    /// Retained across later sign-ins so a peer that missed the tombstone can
    /// still fence its paired device's state from before the clear.
    var clearEpoch: UUID?
    /// A generation received from Watch sync is committed with its identity.
    /// It is a lower bound for every app observing this shared identity.
    var watchClearGeneration: Int?
    /// The clear already accounted for by that generation, if any.
    var watchClearEpoch: UUID?
    var watchPhoneOrdering: [String: WatchSyncPhoneOrdering]?
  }

  let keychain: any KeychainStorage
  let instanceFingerprint: String
  var clearIntentKeychain: (any KeychainStorage)?
  var clearIntentScope = ""
  var preparation: Preparation?
  var watchSyncOwnerIdentifier = Bundle.main.bundleIdentifier ?? "clerk"
  var key: String {
    "\(ClerkKeychainKey.identity.rawValue).\(instanceFingerprint)"
  }

  func prepareForUse() throws {
    try preparation?.run()
  }

  func load() throws -> Record? {
    guard let data = try keychain.dataForConditionalUpdate(forKey: key) else { return nil }
    struct Header: Decodable { let schemaVersion: Int }
    let header = try JSONDecoder.clerkDecoder.decode(Header.self, from: data)
    guard header.schemaVersion == Record.schemaVersion else {
      throw ClerkIdentityStoreError.unsupportedSchemaVersion(header.schemaVersion)
    }
    let record = try JSONDecoder.clerkDecoder.decode(Record.self, from: data)
    guard record.instanceFingerprint == instanceFingerprint else {
      throw ClerkIdentityStoreError.otherInstance
    }
    _ = try record.identity.validated()
    if let generation = record.watchClearGeneration, generation < 0 {
      throw KeychainError.invalidStringEncoding
    }
    return record
  }

  /// Reads only the revision, so checking for another process's write skips decoding the Client.
  func revision() throws -> UUID? {
    struct Header: Decodable {
      let revision: UUID
    }
    guard let data = try keychain.dataForConditionalUpdate(forKey: key) else { return nil }
    return try JSONDecoder.clerkDecoder.decode(Header.self, from: data).revision
  }

  /// Replaces only the snapshot on which the caller based its decision.
  /// Explicit clears retain credential-free records rather than an unversioned absence.
  /// `recordsClear` preserves a newly observed paired-device clear even when its
  /// snapshot already includes a later token. The caller compares the incoming
  /// generation to its local counter; an echo of a known counter is not a new clear.
  @discardableResult
  func save(_ identity: ClerkIdentitySnapshot, replacing expected: Record?, watchClearGeneration: Int? = nil,
            recordsClear: Bool = false, watchPhoneOrdering: WatchSyncPhoneOrdering? = nil) throws -> Record
  {
    try write(identity, replacing: expected, watchClearGeneration: watchClearGeneration,
              recordsClear: recordsClear, watchPhoneOrdering: watchPhoneOrdering)
  }

  /// A backend handoff retains identity and Watch epochs, but starts a new storage revision.
  func importRecord(_ source: Record, replacing expected: Record?) throws {
    guard source.instanceFingerprint == instanceFingerprint else { throw ClerkIdentityStoreError.otherInstance }
    let record = Record(
      schemaVersion: Record.schemaVersion, revision: UUID(), instanceFingerprint: instanceFingerprint,
      identity: source.identity, epoch: source.epoch, clearEpoch: source.clearEpoch,
      watchClearGeneration: source.watchClearGeneration, watchClearEpoch: source.watchClearEpoch,
      watchPhoneOrdering: source.watchPhoneOrdering
    )
    try persist(record, replacing: expected)
  }

  private func write(
    _ identity: ClerkIdentitySnapshot, replacing expected: Record?, clearID: UUID? = nil,
    watchClearGeneration: Int? = nil, recordsClear: Bool = false, watchPhoneOrdering: WatchSyncPhoneOrdering? = nil
  ) throws -> Record {
    let identity = try identity.validated()
    if let watchClearGeneration, watchClearGeneration < 0 { throw KeychainError.invalidStringEncoding }
    let metadataOnly = watchPhoneOrdering != nil && !recordsClear && identity == (expected?.identity ?? .signedOut)
    let epoch: UUID = if metadataOnly {
      expected?.epoch ?? UUID()
    } else if let clearID {
      clearID
    } else if !recordsClear, let expected, identity.deviceToken != nil, identity.deviceToken == expected.identity.deviceToken {
      expected.epoch
    } else {
      UUID()
    }
    let clearEpoch = !metadataOnly && (recordsClear || identity.deviceToken == nil) ? epoch : expected?.clearEpoch
    var phoneOrdering = expected?.watchPhoneOrdering ?? [:]
    if let watchPhoneOrdering { phoneOrdering[watchSyncOwnerIdentifier] = watchPhoneOrdering }
    let record = Record(
      schemaVersion: Record.schemaVersion,
      revision: clearID ?? UUID(),
      instanceFingerprint: instanceFingerprint,
      identity: identity,
      epoch: epoch,
      clearEpoch: clearEpoch,
      watchClearGeneration: watchClearGeneration.map { max($0, expected?.watchClearGeneration ?? 0) }
        ?? expected?.watchClearGeneration,
      watchClearEpoch: watchClearGeneration != nil ? clearEpoch : expected?.watchClearEpoch,
      watchPhoneOrdering: phoneOrdering.isEmpty ? nil : phoneOrdering
    )
    try persist(record, replacing: expected)
    return record
  }

  private func persist(_ record: Record, replacing expected: Record?) throws {
    guard try keychain.compareAndSwap(
      JSONEncoder.clerkEncoder.encode(record),
      forKey: key,
      expectedRevision: expected?.revision,
      newRevision: record.revision
    ) else { throw ClerkIdentityStoreError.writeConflict }
  }

  /// Clears the latest observed identity in one conditional attempt. A competing
  /// write is reported to the caller, which can explicitly retry the clear.
  @discardableResult
  func clear() throws -> Record {
    let intent = ClearIntent()
    try saveClearIntent(intent)
    return try finishClear(intent)
  }

  /// Recovers before hydration or legacy migration can expose credentials. An
  /// already completed clear never clears a subsequently created identity.
  func recoverPendingClear() throws {
    guard let data = try clearJournal.data(forKey: clearIntentKey) else { return }
    _ = try finishClear(JSONDecoder.clerkDecoder.decode(ClearIntent.self, from: data))
  }

  private struct ClearIntent: Codable {
    var id = UUID()
    var observedIdentity = false
    var epoch: UUID?
  }

  var clearIntentKey: String {
    "\(key).pendingClear.\(clearIntentScope)"
  }

  /// App-attributed storage for clear intents and this app's Watch observations.
  var clearJournal: any KeychainStorage {
    clearIntentKeychain ?? keychain
  }

  private func saveClearIntent(_ intent: ClearIntent) throws {
    try clearJournal.set(JSONEncoder.clerkEncoder.encode(intent), forKey: clearIntentKey)
  }

  private func finishClear(_ intent: ClearIntent) throws -> Record {
    var intent = intent
    let current = try load()
    if intent.observedIdentity, let current, current.epoch != intent.epoch {
      // The clear committed, or another transition replaced its identity. Either
      // way, an unfinished cleanup must not clear that later identity.
      try clearJournal.deleteItem(forKey: clearIntentKey)
      return current
    }
    intent.observedIdentity = true
    intent.epoch = current?.epoch
    try saveClearIntent(intent)
    let cleared = try write(.signedOut, replacing: current, clearID: intent.id)
    try clearJournal.deleteItem(forKey: clearIntentKey)
    return cleared
  }
}
