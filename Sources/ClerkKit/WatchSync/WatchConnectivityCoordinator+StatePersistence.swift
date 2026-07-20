//
//  WatchConnectivityCoordinator+StatePersistence.swift
//  Clerk
//

import CryptoKit
import Foundation

struct WatchSyncPendingMetadataIntent {
  let source: WatchSyncSource
  let deviceToken: String?
  let client: Client?
  let serverDate: Date?
  let tokenVersion: WatchSyncVersion?
  let authVersion: WatchSyncVersion?
}

enum WatchSyncMetadataState: String, Codable, Equatable {
  case set
  case cleared
}

struct WatchSyncMetadataRecord: Codable, Equatable {
  var deviceTokenState: WatchSyncMetadataState?
  var deviceTokenVersion: Int?
  var deviceTokenFingerprint: String?
  var deviceTokenSource: WatchSyncSource?
  var authState: WatchSyncMetadataState?
  var authVersion: Int?
  var authFingerprint: String?
  var authSource: WatchSyncSource?
  var pendingDeviceTokenState: WatchSyncMetadataState?
  var pendingDeviceTokenVersion: Int?
  var pendingDeviceTokenFingerprint: String?
  var pendingDeviceTokenSource: WatchSyncSource?
  var pendingAuthState: WatchSyncMetadataState?
  var pendingAuthVersion: Int?
  var pendingAuthFingerprint: String?
  var pendingAuthSource: WatchSyncSource?

  static let empty = WatchSyncMetadataRecord()

  var effectiveDeviceTokenVersion: Int {
    max(deviceTokenVersion ?? 0, pendingDeviceTokenVersion ?? 0)
  }

  var effectiveAuthVersion: Int {
    max(authVersion ?? 0, pendingAuthVersion ?? 0)
  }

  var effectiveDeviceTokenSource: WatchSyncSource? {
    guard let pendingDeviceTokenVersion else { return deviceTokenSource }
    guard let deviceTokenVersion else { return pendingDeviceTokenSource }
    return pendingDeviceTokenVersion >= deviceTokenVersion ? pendingDeviceTokenSource : deviceTokenSource
  }

  var effectiveDeviceTokenFingerprint: String? {
    guard let pendingDeviceTokenVersion else { return deviceTokenFingerprint }
    guard let deviceTokenVersion else { return pendingDeviceTokenFingerprint }
    return pendingDeviceTokenVersion >= deviceTokenVersion ? pendingDeviceTokenFingerprint : deviceTokenFingerprint
  }

  var effectiveAuthSource: WatchSyncSource? {
    guard let pendingAuthVersion else { return authSource }
    guard let authVersion else { return pendingAuthSource }
    return pendingAuthVersion >= authVersion ? pendingAuthSource : authSource
  }

  var effectiveAuthFingerprint: String? {
    guard let pendingAuthVersion else { return authFingerprint }
    guard let authVersion else { return pendingAuthFingerprint }
    return pendingAuthVersion >= authVersion ? pendingAuthFingerprint : authFingerprint
  }

  var effectiveDeviceTokenState: WatchSyncMetadataState? {
    guard let pendingDeviceTokenVersion else { return deviceTokenState }
    guard let deviceTokenVersion else { return pendingDeviceTokenState }
    return pendingDeviceTokenVersion >= deviceTokenVersion ? pendingDeviceTokenState : deviceTokenState
  }

  var effectiveAuthState: WatchSyncMetadataState? {
    guard let pendingAuthVersion else { return authState }
    guard let authVersion else { return pendingAuthState }
    return pendingAuthVersion >= authVersion ? pendingAuthState : authState
  }

  var hasPendingIdentityMetadata: Bool {
    pendingDeviceTokenVersion != nil || pendingAuthVersion != nil
  }

  mutating func promotePendingDeviceToken(version: WatchSyncVersion) {
    guard pendingDeviceTokenVersion == version.rawValue else { return }
    deviceTokenState = pendingDeviceTokenState
    deviceTokenVersion = pendingDeviceTokenVersion
    deviceTokenFingerprint = pendingDeviceTokenFingerprint
    deviceTokenSource = pendingDeviceTokenSource
    pendingDeviceTokenState = nil
    pendingDeviceTokenVersion = nil
    pendingDeviceTokenFingerprint = nil
    pendingDeviceTokenSource = nil
  }

  mutating func promotePendingAuth(version: WatchSyncVersion) {
    guard pendingAuthVersion == version.rawValue else { return }
    authState = pendingAuthState
    authVersion = pendingAuthVersion
    authFingerprint = pendingAuthFingerprint
    authSource = pendingAuthSource
    pendingAuthState = nil
    pendingAuthVersion = nil
    pendingAuthFingerprint = nil
    pendingAuthSource = nil
  }

  mutating func discardPendingDeviceToken() {
    pendingDeviceTokenState = nil
    pendingDeviceTokenVersion = nil
    pendingDeviceTokenFingerprint = nil
    pendingDeviceTokenSource = nil
  }

  mutating func discardPendingAuth() {
    pendingAuthState = nil
    pendingAuthVersion = nil
    pendingAuthFingerprint = nil
    pendingAuthSource = nil
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

    let deviceToken = try decodeLegacyPair(
      state: legacyString(for: .watchSyncDeviceTokenState),
      version: legacyString(for: .watchSyncDeviceTokenVersion)
    )
    let auth = try decodeLegacyPair(
      state: legacyString(for: .watchSyncAuthState),
      version: legacyString(for: .watchSyncAuthVersion)
    )
    let legacy = WatchSyncMetadataRecord(
      deviceTokenState: deviceToken.state,
      deviceTokenVersion: deviceToken.version,
      authState: auth.state,
      authVersion: auth.version
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

    record.deviceTokenState = .cleared
    record.deviceTokenVersion = clearVersion
    record.deviceTokenFingerprint = WatchConnectivityCoordinator.deviceTokenFingerprint(nil)
    record.deviceTokenSource = nil
    record.authState = .cleared
    record.authVersion = clearVersion
    record.authFingerprint = try WatchConnectivityCoordinator.authFingerprint(
      client: nil,
      serverDate: nil
    )
    record.authSource = nil
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
      && isValidAcceptedSource(
        record.deviceTokenSource,
        state: record.deviceTokenState,
        version: record.deviceTokenVersion
      )
      && isValidAcceptedFingerprint(
        record.authFingerprint,
        state: record.authState,
        version: record.authVersion
      )
      && isValidAcceptedSource(
        record.authSource,
        state: record.authState,
        version: record.authVersion
      )
      && isValidPendingTriple(
        state: record.pendingDeviceTokenState,
        version: record.pendingDeviceTokenVersion,
        fingerprint: record.pendingDeviceTokenFingerprint,
        source: record.pendingDeviceTokenSource,
        acceptedVersion: record.deviceTokenVersion
      )
      && isValidPendingTriple(
        state: record.pendingAuthState,
        version: record.pendingAuthVersion,
        fingerprint: record.pendingAuthFingerprint,
        source: record.pendingAuthSource,
        acceptedVersion: record.authVersion
      )
  }

  private func isValidPair(state: WatchSyncMetadataState?, version: Int?) -> Bool {
    guard (state == nil) == (version == nil) else { return false }
    guard let version else { return true }
    return version >= 0
  }

  private func isValidAcceptedFingerprint(
    _ fingerprint: String?,
    state: WatchSyncMetadataState?,
    version: Int?
  ) -> Bool {
    guard let fingerprint else { return true }
    return state != nil && version != nil && !fingerprint.isEmpty
  }

  private func isValidAcceptedSource(
    _ source: WatchSyncSource?,
    state: WatchSyncMetadataState?,
    version: Int?
  ) -> Bool {
    guard source != nil else { return true }
    return state != nil && version != nil
  }

  private func isValidPendingTriple(
    state: WatchSyncMetadataState?,
    version: Int?,
    fingerprint: String?,
    source: WatchSyncSource?,
    acceptedVersion: Int?
  ) -> Bool {
    guard (state == nil) == (version == nil),
          (version == nil) == (fingerprint == nil)
    else {
      return false
    }
    guard source == nil || version != nil else { return false }
    guard let version, let fingerprint else { return true }
    return version >= (acceptedVersion ?? 0) && !fingerprint.isEmpty
  }

  private func legacyString(for key: ClerkKeychainKey) throws -> String? {
    do {
      return try keychain.string(forKey: key.rawValue)
    } catch KeychainError.invalidStringEncoding {
      throw WatchSyncMetadataStoreError.corrupt
    }
  }

  private func decodeLegacyPair(
    state rawState: String?,
    version rawVersion: String?
  ) throws -> (state: WatchSyncMetadataState?, version: Int?) {
    let state = try decodeLegacyState(rawState)
    let version = try decodeLegacyVersion(rawVersion)

    switch (state, version) {
    case let (.some(state), .some(version)):
      return (state, version)
    case let (.some(state), nil):
      return (state, WatchSyncVersion.initial.rawValue)
    case (nil, nil):
      return (nil, nil)
    case (nil, .some):
      throw WatchSyncMetadataStoreError.corrupt
    }
  }

  private func decodeLegacyState(_ value: String?) throws -> WatchSyncMetadataState? {
    guard let value else { return nil }
    guard let state = WatchSyncMetadataState(rawValue: value) else {
      throw WatchSyncMetadataStoreError.corrupt
    }
    return state
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

  func persistAuthState(
    _ state: WatchSyncMetadataState,
    version: WatchSyncVersion?,
    client: Client?,
    serverDate: Date?,
    keychain: any KeychainStorage
  ) throws -> WatchSyncMetadataRecord {
    let store = WatchSyncMetadataStore(keychain: keychain)
    var record = try store.load()
    let resolvedVersion = try version ?? WatchSyncVersion(
      rawValue: record.effectiveAuthVersion
    ).next()
    record.authState = state
    record.authVersion = resolvedVersion.rawValue
    record.authFingerprint = try Self.authFingerprint(
      client: client,
      serverDate: serverDate
    )
    record.authSource = nil
    record.discardPendingAuth()
    try store.save(record)
    setAuthGeneration(resolvedVersion)
    return record
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
      resetAcceptedDeviceTokenWatermarkIfNeeded(
        in: &record,
        version: tokenVersion,
        source: intent.source
      )
      guard record.pendingDeviceTokenVersion != tokenVersion.rawValue
        || record.pendingDeviceTokenFingerprint == fingerprint
      else {
        throw ClerkClientError(message: "Conflicting Watch token payload reused a pending version.")
      }
      record.pendingDeviceTokenState = intent.deviceToken == nil ? .cleared : .set
      record.pendingDeviceTokenVersion = tokenVersion.rawValue
      record.pendingDeviceTokenFingerprint = fingerprint
      record.pendingDeviceTokenSource = intent.source
    }
    if let authVersion = intent.authVersion {
      let fingerprint = try Self.authFingerprint(
        client: intent.client,
        serverDate: intent.serverDate
      )
      resetAcceptedAuthWatermarkIfNeeded(
        in: &record,
        version: authVersion,
        source: intent.source
      )
      guard record.pendingAuthVersion != authVersion.rawValue
        || record.pendingAuthFingerprint == fingerprint
      else {
        throw ClerkClientError(message: "Conflicting Watch auth payload reused a pending version.")
      }
      record.pendingAuthState = intent.client == nil ? .cleared : .set
      record.pendingAuthVersion = authVersion.rawValue
      record.pendingAuthFingerprint = fingerprint
      record.pendingAuthSource = intent.source
    }
    try store.save(record)
  }

  private func resetAcceptedDeviceTokenWatermarkIfNeeded(
    in record: inout WatchSyncMetadataRecord,
    version: WatchSyncVersion,
    source: WatchSyncSource
  ) {
    guard source.incomingDeviceIsAuthoritative,
          version.rawValue < record.effectiveDeviceTokenVersion,
          record.effectiveDeviceTokenState != .cleared,
          record.effectiveDeviceTokenSource != source
    else {
      return
    }
    record.deviceTokenState = nil
    record.deviceTokenVersion = nil
    record.deviceTokenFingerprint = nil
    record.deviceTokenSource = nil
    record.discardPendingDeviceToken()
  }

  private func resetAcceptedAuthWatermarkIfNeeded(
    in record: inout WatchSyncMetadataRecord,
    version: WatchSyncVersion,
    source: WatchSyncSource
  ) {
    guard source.incomingDeviceIsAuthoritative,
          version.rawValue < record.effectiveAuthVersion,
          record.effectiveAuthState != .cleared,
          record.effectiveAuthSource != source
    else {
      return
    }
    record.authState = nil
    record.authVersion = nil
    record.authFingerprint = nil
    record.authSource = nil
    record.discardPendingAuth()
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

  func discardPendingWatchMetadata(
    tokenVersion: WatchSyncVersion?,
    authVersion: WatchSyncVersion?,
    keychain: any KeychainStorage
  ) throws {
    guard tokenVersion != nil || authVersion != nil else { return }
    let store = WatchSyncMetadataStore(keychain: keychain)
    var record = try store.load()
    var didChange = false
    if let tokenVersion,
       record.pendingDeviceTokenVersion == tokenVersion.rawValue
    {
      record.discardPendingDeviceToken()
      didChange = true
    }
    if let authVersion,
       record.pendingAuthVersion == authVersion.rawValue
    {
      record.discardPendingAuth()
      didChange = true
    }
    if didChange {
      try store.save(record)
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
    let payload = ClerkIdentitySnapshot(
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
