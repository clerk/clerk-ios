//
//  SharedSessionSyncAdoption.swift
//  Clerk
//

import Foundation

struct SharedSessionSyncAdoption {
  static let markerValue = "2"

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
      let appLocalIdentitySources = [
        configuredAppLocalIdentity,
        previousAppLocalIdentity,
      ].compactMap { $0 }
      var migratedAppLocalIdentity = false
      for source in appLocalIdentitySources {
        if let identity = try loadCoherentIdentity(from: source) {
          try destinationIdentityStore.saveLegacyAdoption(identity)
          migratedAppLocalIdentity = true
          break
        }
      }
      if !migratedAppLocalIdentity,
         let identity = try loadCoherentIdentity(from: legacyShared)
      {
        try destinationIdentityStore.save(identity)
      }
    }

    try migrateEnvironmentIfNeeded()
    try migratePrivateAppStateIfNeeded()
    try destinationIdentity.set(
      Self.markerValue,
      forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
    )
  }

  func markAdoptedWithoutMigratingCredentials() throws {
    try destinationIdentity.set(
      Self.markerValue,
      forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
    )
  }

  private func loadCoherentIdentity(
    from keychain: any KeychainStorage
  ) throws -> SharedSessionLocalIdentity? {
    guard let tokenData = try keychain.data(
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    ),
      let deviceToken = decodeString(tokenData)?.trimmingCharacters(in: .whitespacesAndNewlines),
      !deviceToken.isEmpty
    else {
      return nil
    }

    // Legacy token, Client, and date values were written as independent Keychain
    // items, so no read protocol can prove that they belong to one revision. Keep
    // only the credential needed for a canonical refresh and let that response
    // establish the first atomic Client snapshot.
    return try SharedSessionLocalIdentity(
      state: .cleared,
      deviceToken: deviceToken,
      client: nil,
      serverDate: nil
    ).validated()
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
}
