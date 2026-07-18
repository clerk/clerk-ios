//
//  WatchConnectivityCoordinator+StatePersistence.swift
//  Clerk
//

import CryptoKit
import Foundation

struct WatchSyncPendingMetadataIntent {
  let deviceToken: String?
  let client: Client?
  let serverDate: Date?
  let tokenVersion: WatchSyncVersion?
  let authVersion: WatchSyncVersion?
}

struct WatchSyncMetadataRecord: Codable, Equatable {
  var deviceTokenState: String?
  var deviceTokenVersion: Int?
  var deviceTokenFingerprint: String?
  var authState: String?
  var authVersion: Int?
  var authFingerprint: String?
  var pendingDeviceTokenState: String?
  var pendingDeviceTokenVersion: Int?
  var pendingDeviceTokenFingerprint: String?
  var pendingAuthState: String?
  var pendingAuthVersion: Int?
  var pendingAuthFingerprint: String?

  static let empty = WatchSyncMetadataRecord()

  var effectiveDeviceTokenVersion: Int {
    max(deviceTokenVersion ?? 0, pendingDeviceTokenVersion ?? 0)
  }

  var effectiveAuthVersion: Int {
    max(authVersion ?? 0, pendingAuthVersion ?? 0)
  }

  var hasPendingIdentityMetadata: Bool {
    pendingDeviceTokenVersion != nil || pendingAuthVersion != nil
  }

  mutating func promotePendingDeviceToken(version: WatchSyncVersion) {
    guard pendingDeviceTokenVersion == version.rawValue else { return }
    deviceTokenState = pendingDeviceTokenState
    deviceTokenVersion = pendingDeviceTokenVersion
    deviceTokenFingerprint = pendingDeviceTokenFingerprint
    pendingDeviceTokenState = nil
    pendingDeviceTokenVersion = nil
    pendingDeviceTokenFingerprint = nil
  }

  mutating func promotePendingAuth(version: WatchSyncVersion) {
    guard pendingAuthVersion == version.rawValue else { return }
    authState = pendingAuthState
    authVersion = pendingAuthVersion
    authFingerprint = pendingAuthFingerprint
    pendingAuthState = nil
    pendingAuthVersion = nil
    pendingAuthFingerprint = nil
  }

  mutating func discardPendingDeviceToken() {
    pendingDeviceTokenState = nil
    pendingDeviceTokenVersion = nil
    pendingDeviceTokenFingerprint = nil
  }

  mutating func discardPendingAuth() {
    pendingAuthState = nil
    pendingAuthVersion = nil
    pendingAuthFingerprint = nil
  }
}

enum WatchSyncMetadataStoreError: Error, Equatable {
  case corrupt
}

struct WatchSyncMetadataStore {
  let keychain: any KeychainStorage

  func load() throws -> WatchSyncMetadataRecord {
    if let data = try keychain.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue) {
      let record: WatchSyncMetadataRecord
      do {
        record = try JSONDecoder.clerkDecoder.decode(WatchSyncMetadataRecord.self, from: data)
      } catch {
        throw WatchSyncMetadataStoreError.corrupt
      }
      guard isValid(record) else {
        throw WatchSyncMetadataStoreError.corrupt
      }
      return record
    }

    let deviceTokenVersion = try decodeLegacyVersion(
      keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue)
    )
    let authVersion = try decodeLegacyVersion(
      keychain.string(forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue)
    )
    let legacy = try WatchSyncMetadataRecord(
      deviceTokenState: keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue),
      deviceTokenVersion: deviceTokenVersion,
      authState: keychain.string(forKey: ClerkKeychainKey.watchSyncAuthState.rawValue),
      authVersion: authVersion
    )
    guard isValid(legacy) else {
      throw WatchSyncMetadataStoreError.corrupt
    }
    if legacy != .empty {
      try save(legacy)
    }
    return legacy
  }

  func save(_ record: WatchSyncMetadataRecord) throws {
    guard isValid(record) else {
      throw WatchSyncMetadataStoreError.corrupt
    }
    try keychain.set(
      JSONEncoder.clerkEncoder.encode(record),
      forKey: ClerkKeychainKey.watchSyncMetadata.rawValue
    )
  }

  @MainActor
  func saveClearTombstone(minimumVersion: Int? = nil) throws -> WatchSyncMetadataRecord {
    var record: WatchSyncMetadataRecord
    do {
      record = try load()
    } catch WatchSyncMetadataStoreError.corrupt {
      record = .empty
    }
    let currentVersion = max(record.effectiveDeviceTokenVersion, record.effectiveAuthVersion)
    guard currentVersion < Int.max else {
      throw ClerkClientError(message: "Watch identity metadata version is exhausted.")
    }
    let wallClockVersion = Int(Date().timeIntervalSince1970 * 1000)
    let clearVersion = max(currentVersion + 1, minimumVersion ?? wallClockVersion)

    record.deviceTokenState = "cleared"
    record.deviceTokenVersion = clearVersion
    record.deviceTokenFingerprint = WatchConnectivityCoordinator.deviceTokenFingerprint(nil)
    record.authState = "cleared"
    record.authVersion = clearVersion
    record.authFingerprint = try WatchConnectivityCoordinator.authFingerprint(
      client: nil,
      serverDate: nil
    )
    record.discardPendingDeviceToken()
    record.discardPendingAuth()
    try save(record)
    return record
  }

  private func isValid(_ record: WatchSyncMetadataRecord) -> Bool {
    isValidPair(state: record.deviceTokenState, version: record.deviceTokenVersion)
      && isValidPair(state: record.authState, version: record.authVersion)
      && isValidAcceptedFingerprint(
        record.deviceTokenFingerprint,
        state: record.deviceTokenState,
        version: record.deviceTokenVersion
      )
      && isValidAcceptedFingerprint(
        record.authFingerprint,
        state: record.authState,
        version: record.authVersion
      )
      && isValidPendingTriple(
        state: record.pendingDeviceTokenState,
        version: record.pendingDeviceTokenVersion,
        fingerprint: record.pendingDeviceTokenFingerprint,
        acceptedVersion: record.deviceTokenVersion
      )
      && isValidPendingTriple(
        state: record.pendingAuthState,
        version: record.pendingAuthVersion,
        fingerprint: record.pendingAuthFingerprint,
        acceptedVersion: record.authVersion
      )
  }

  private func isValidPair(state: String?, version: Int?) -> Bool {
    guard (state == nil) == (version == nil) else { return false }
    guard let state, let version else { return true }
    return (state == "set" || state == "cleared") && version >= 0
  }

  private func isValidAcceptedFingerprint(
    _ fingerprint: String?,
    state: String?,
    version: Int?
  ) -> Bool {
    guard let fingerprint else { return true }
    return state != nil && version != nil && !fingerprint.isEmpty
  }

  private func isValidPendingTriple(
    state: String?,
    version: Int?,
    fingerprint: String?,
    acceptedVersion: Int?
  ) -> Bool {
    guard (state == nil) == (version == nil),
          (version == nil) == (fingerprint == nil)
    else {
      return false
    }
    guard let state, let version, let fingerprint else { return true }
    return (state == "set" || state == "cleared")
      && version >= (acceptedVersion ?? 0)
      && !fingerprint.isEmpty
  }

  private func decodeLegacyVersion(_ value: String?) throws -> Int? {
    guard let value else { return nil }
    guard let version = Int(value), version >= 0 else {
      throw WatchSyncMetadataStoreError.corrupt
    }
    return version
  }
}

extension WatchConnectivityCoordinator {
  func readAuthVersion(keychain: any KeychainStorage) throws -> WatchSyncVersion {
    try WatchSyncVersion(
      rawValue: WatchSyncMetadataStore(keychain: keychain).load().effectiveAuthVersion
    )
  }

  func nextAuthVersion(keychain: any KeychainStorage) throws -> WatchSyncVersion {
    try readAuthVersion(keychain: keychain).next()
  }

  func persistAuthState(
    _ state: String,
    version: WatchSyncVersion,
    client: Client?,
    serverDate: Date?,
    keychain: any KeychainStorage
  ) throws {
    let store = WatchSyncMetadataStore(keychain: keychain)
    var record = try store.load()
    record.authState = state
    record.authVersion = version.rawValue
    record.authFingerprint = try Self.authFingerprint(
      client: client,
      serverDate: serverDate
    )
    record.discardPendingAuth()
    try store.save(record)
    setAuthGeneration(version)
  }

  func stagePendingWatchMetadata(
    _ intent: WatchSyncPendingMetadataIntent,
    keychain: any KeychainStorage
  ) throws {
    guard intent.tokenVersion != nil || intent.authVersion != nil else { return }
    let store = WatchSyncMetadataStore(keychain: keychain)
    var record = try store.load()
    if let tokenVersion = intent.tokenVersion {
      let fingerprint = Self.deviceTokenFingerprint(intent.deviceToken)
      guard record.pendingDeviceTokenVersion != tokenVersion.rawValue
        || record.pendingDeviceTokenFingerprint == fingerprint
      else {
        throw ClerkClientError(message: "Conflicting Watch token payload reused a pending version.")
      }
      record.pendingDeviceTokenState = intent.deviceToken == nil ? "cleared" : "set"
      record.pendingDeviceTokenVersion = tokenVersion.rawValue
      record.pendingDeviceTokenFingerprint = fingerprint
    }
    if let authVersion = intent.authVersion {
      let fingerprint = try Self.authFingerprint(
        client: intent.client,
        serverDate: intent.serverDate
      )
      guard record.pendingAuthVersion != authVersion.rawValue
        || record.pendingAuthFingerprint == fingerprint
      else {
        throw ClerkClientError(message: "Conflicting Watch auth payload reused a pending version.")
      }
      record.pendingAuthState = intent.client == nil ? "cleared" : "set"
      record.pendingAuthVersion = authVersion.rawValue
      record.pendingAuthFingerprint = fingerprint
    }
    try store.save(record)
  }

  func promotePendingWatchMetadata(
    tokenVersion: WatchSyncVersion?,
    authVersion: WatchSyncVersion?,
    keychain: any KeychainStorage
  ) throws {
    guard tokenVersion != nil || authVersion != nil else { return }
    let store = WatchSyncMetadataStore(keychain: keychain)
    var record = try store.load()
    if let tokenVersion {
      record.promotePendingDeviceToken(version: tokenVersion)
    }
    if let authVersion {
      record.promotePendingAuth(version: authVersion)
    }
    try store.save(record)
    if let authVersion,
       record.authVersion == authVersion.rawValue
    {
      setAuthGeneration(authVersion)
    }
  }

  func resolvedWatchMetadata(
    clerk: Clerk,
    keychain: any KeychainStorage
  ) throws -> WatchSyncMetadataRecord {
    let store = WatchSyncMetadataStore(keychain: keychain)
    var record = try store.load()
    guard record.hasPendingIdentityMetadata else { return record }
    var didResolve = false
    var resolvedAuthVersion: WatchSyncVersion?

    if let version = record.pendingDeviceTokenVersion,
       record.pendingDeviceTokenFingerprint == Self.deviceTokenFingerprint(clerk.deviceToken)
    {
      record.promotePendingDeviceToken(version: WatchSyncVersion(rawValue: version))
      didResolve = true
    }
    if let version = record.pendingAuthVersion,
       try record.pendingAuthFingerprint == (Self.authFingerprint(
         client: clerk.client,
         serverDate: clerk.lastClientServerFetchDate
       ))
    {
      let authVersion = WatchSyncVersion(rawValue: version)
      record.promotePendingAuth(version: authVersion)
      resolvedAuthVersion = authVersion
      didResolve = true
    }
    if didResolve {
      try store.save(record)
      if let resolvedAuthVersion {
        setAuthGeneration(resolvedAuthVersion)
      }
    }
    guard !record.hasPendingIdentityMetadata else {
      throw ClerkClientError(message: "A Watch identity metadata transition is still pending.")
    }
    return record
  }

  static func deviceTokenFingerprint(_ deviceToken: String?) -> String {
    fingerprint(Data((deviceToken.map { "set\u{0}\($0)" } ?? "cleared").utf8))
  }

  static func authFingerprint(client: Client?, serverDate: Date?) throws -> String {
    let payload = SharedSessionIdentityPayload(
      state: client == nil ? .cleared : .present,
      deviceToken: client == nil ? nil : "paired",
      client: client,
      serverDate: serverDate
    )
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.dateEncodingStrategy = .millisecondsSince1970
    encoder.outputFormatting = .sortedKeys
    return try fingerprint(encoder.encode(payload))
  }

  private static func fingerprint(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
