//
//  SharedSessionSyncAdoption.swift
//  Clerk
//

import Foundation

struct SharedSessionSyncAdoption {
  static let markerValue = "2"
  private static let maximumSnapshotValidationRetries = 3

  enum AdoptionError: Error, Equatable {
    case unstableLegacyIdentity
  }

  private struct LegacyIdentitySnapshot: Equatable {
    let token: Data?
    let client: Data?
    let serverDate: Data?
  }

  private let destinationIdentity: any KeychainStorage
  private let destinationIdentityStore: any SharedSessionLocalIdentityStoring
  private let destinationPrivate: any KeychainStorage
  private let configuredAppLocalIdentity: (any KeychainStorage)?
  private let previousAppLocalIdentity: (any KeychainStorage)?
  private let legacyShared: any KeychainStorage

  init(
    destinationIdentity: any KeychainStorage,
    destinationPrivate: any KeychainStorage,
    configuredAppLocalIdentity: (any KeychainStorage)? = nil,
    previousAppLocalIdentity: (any KeychainStorage)?,
    legacyShared: any KeychainStorage
  ) {
    self.destinationIdentity = destinationIdentity
    destinationIdentityStore = SharedSessionLocalIdentityStore(keychain: destinationIdentity)
    self.destinationPrivate = destinationPrivate
    self.configuredAppLocalIdentity = configuredAppLocalIdentity
    self.previousAppLocalIdentity = previousAppLocalIdentity
    self.legacyShared = legacyShared
  }

  static func isAdopted(in identityKeychain: any KeychainStorage) throws -> Bool {
    try identityKeychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue) == markerValue
  }

  func migrateIfNeeded() throws {
    guard try !Self.isAdopted(in: destinationIdentity) else {
      return
    }

    if try destinationIdentityStore.load() == nil {
      let identitySources = [
        configuredAppLocalIdentity,
        previousAppLocalIdentity,
        legacyShared,
      ].compactMap { $0 }
      for source in identitySources {
        if let identity = try loadCoherentIdentity(from: source) {
          try destinationIdentityStore.save(identity)
          break
        }
      }
    }

    try migrateEnvironmentIfNeeded()
    try migratePrivateAppStateIfNeeded()
    try destinationIdentity.set(
      Self.markerValue,
      forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
    )
  }

  private func loadCoherentIdentity(
    from keychain: any KeychainStorage
  ) throws -> SharedSessionLocalIdentity? {
    let snapshot = try loadStableIdentitySnapshot(from: keychain)
    let tokenData = snapshot.token
    let clientData = snapshot.client
    let serverDateData = snapshot.serverDate
    guard tokenData != nil || clientData != nil || serverDateData != nil else {
      return nil
    }

    let deviceToken: String?
    if let tokenData {
      guard let decoded = decodeString(tokenData)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !decoded.isEmpty
      else {
        return nil
      }
      deviceToken = decoded
    } else {
      deviceToken = nil
    }

    let client: Client?
    if let clientData {
      guard deviceToken != nil,
            let decoded = try? JSONDecoder.clerkDecoder.decode(Client.self, from: clientData)
      else {
        return nil
      }
      client = decoded
    } else {
      client = nil
    }

    let serverDate: Date?
    if let serverDateData {
      guard let decoded = decodeServerDate(serverDateData) else {
        return nil
      }
      serverDate = decoded
    } else {
      serverDate = nil
    }

    guard deviceToken != nil || client != nil else {
      return nil
    }
    return try? SharedSessionLocalIdentity(
      state: client == nil ? .cleared : .present,
      deviceToken: deviceToken,
      client: client,
      serverDate: serverDate
    ).validated()
  }

  private func loadStableIdentitySnapshot(
    from keychain: any KeychainStorage
  ) throws -> LegacyIdentitySnapshot {
    var previous = try loadIdentitySnapshot(from: keychain)
    for _ in 0 ..< Self.maximumSnapshotValidationRetries {
      let current = try loadIdentitySnapshot(from: keychain)
      if current == previous {
        return current
      }
      previous = current
    }
    throw AdoptionError.unstableLegacyIdentity
  }

  private func loadIdentitySnapshot(
    from keychain: any KeychainStorage
  ) throws -> LegacyIdentitySnapshot {
    try LegacyIdentitySnapshot(
      token: keychain.data(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue),
      client: keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue),
      serverDate: keychain.data(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
    )
  }

  private func migrateEnvironmentIfNeeded() throws {
    let key = ClerkKeychainKey.cachedEnvironment.rawValue
    guard try destinationPrivate.data(forKey: key) == nil else {
      return
    }

    for source in allLegacySources {
      guard let data = try source.data(forKey: key) else { continue }
      guard (try? JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: data)) != nil else {
        continue
      }
      try destinationPrivate.set(data, forKey: key)
      return
    }
  }

  private func migratePrivateAppStateIfNeeded() throws {
    try migratePrivateValueIfNeeded(for: .pendingMagicLinkFlow) { data in
      guard let flow = try? JSONDecoder.clerkDecoder.decode(PendingMagicLinkFlow.self, from: data) else {
        return false
      }
      return flow.expiresAt > Date()
    }
    try migratePrivateValueIfNeeded(for: .attestKeyId) { data in
      guard let value = decodeString(data)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
        return false
      }
      return !value.isEmpty
    }
  }

  private func migratePrivateValueIfNeeded(
    for key: ClerkKeychainKey,
    isValid: (Data) -> Bool
  ) throws {
    guard try destinationPrivate.data(forKey: key.rawValue) == nil else { return }

    for source in appLocalLegacySources {
      guard let data = try source.data(forKey: key.rawValue), isValid(data) else {
        continue
      }
      try destinationPrivate.set(data, forKey: key.rawValue)
      return
    }
  }

  private var allLegacySources: [any KeychainStorage] {
    [configuredAppLocalIdentity, previousAppLocalIdentity, legacyShared].compactMap { $0 }
  }

  private var appLocalLegacySources: [any KeychainStorage] {
    [configuredAppLocalIdentity, previousAppLocalIdentity].compactMap { $0 }
  }

  private func decodeString(_ data: Data) -> String? {
    String(data: data, encoding: .utf8)
  }

  private func decodeServerDate(_ data: Data) -> Date? {
    guard let value = decodeString(data),
          let interval = TimeInterval(value),
          interval.isFinite
    else {
      return nil
    }
    return Date(timeIntervalSince1970: interval)
  }
}
