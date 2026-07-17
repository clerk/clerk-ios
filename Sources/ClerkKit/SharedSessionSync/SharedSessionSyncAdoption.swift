//
//  SharedSessionSyncAdoption.swift
//  Clerk
//

import Foundation

struct SharedSessionSyncAdoption {
  private static let markerValue = "1"

  private struct IdentitySource {
    let keychain: any KeychainStorage
    let serverDate: TimeInterval?
    let itemCount: Int
  }

  private static let identityKeys: [ClerkKeychainKey] = [
    .clerkDeviceToken,
    .cachedClient,
    .cachedClientServerDate,
  ]

  private static let legacySharedKeys: [ClerkKeychainKey] = [
    .cachedClient,
    .cachedClientServerDate,
    .cachedEnvironment,
    .clerkDeviceToken,
    .sharedSessionSyncAuthState,
    .sharedSessionSyncAuthVersion,
    .sharedSessionSyncEnvironmentVersion,
    .sharedSessionSyncDeviceTokenState,
    .sharedSessionSyncDeviceTokenVersion,
  ]

  static func isAdopted(in keychain: any KeychainStorage) throws -> Bool {
    try keychain.string(
      forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
    ) == markerValue
  }

  static func identityKeychain(
    shared: any KeychainStorage,
    appLocal: any KeychainStorage,
    syncEnabled: Bool
  ) throws -> any KeychainStorage {
    if syncEnabled {
      return appLocal
    }
    return try isAdopted(in: appLocal) ? appLocal : shared
  }

  private let destination: any KeychainStorage
  private let sources: [any KeychainStorage]
  private let legacySharedKeychain: any KeychainStorage

  init(
    destination: any KeychainStorage,
    sources: [any KeychainStorage],
    legacySharedKeychain: any KeychainStorage
  ) {
    self.destination = destination
    self.sources = sources
    self.legacySharedKeychain = legacySharedKeychain
  }

  func migrateIfNeeded() throws {
    if try !Self.isAdopted(in: destination) {
      let identitySource = try preferredIdentitySource()
      if let identitySource {
        try replaceIdentity(with: identitySource)
      }

      let environmentKey = ClerkKeychainKey.cachedEnvironment
      if try destination.data(forKey: environmentKey.rawValue) == nil,
         let source = try ([identitySource].compactMap(\.self) + sources).first(where: {
           try $0.data(forKey: environmentKey.rawValue) != nil
         })
      {
        try copy(environmentKey, from: source)
      }

      try destination.set(
        Self.markerValue,
        forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
      )
    }

    try deleteLegacySharedKeys()
  }

  private func preferredIdentitySource() throws -> (any KeychainStorage)? {
    var selected: IdentitySource?

    for keychain in [destination] + sources {
      let itemCount = try Self.identityKeys.reduce(into: 0) { count, key in
        if try keychain.data(forKey: key.rawValue) != nil {
          count += 1
        }
      }
      guard itemCount > 0 else { continue }

      let date = try keychain
        .string(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
        .flatMap(TimeInterval.init)

      guard let current = selected else {
        selected = IdentitySource(
          keychain: keychain,
          serverDate: date,
          itemCount: itemCount
        )
        continue
      }

      let candidateDate = date ?? -.greatestFiniteMagnitude
      let currentDate = current.serverDate ?? -.greatestFiniteMagnitude
      if candidateDate > currentDate
        || (candidateDate == currentDate && itemCount > current.itemCount)
      {
        selected = IdentitySource(
          keychain: keychain,
          serverDate: date,
          itemCount: itemCount
        )
      }
    }

    return selected?.keychain
  }

  private func replaceIdentity(
    with source: any KeychainStorage
  ) throws {
    for key in Self.identityKeys {
      if let data = try source.data(forKey: key.rawValue) {
        try destination.set(data, forKey: key.rawValue)
      } else {
        try destination.deleteItem(forKey: key.rawValue)
      }
    }
  }

  private func copy(
    _ key: ClerkKeychainKey,
    from source: any KeychainStorage
  ) throws {
    guard let data = try source.data(forKey: key.rawValue) else { return }
    try destination.set(data, forKey: key.rawValue)
  }

  private func deleteLegacySharedKeys() throws {
    for key in Self.legacySharedKeys {
      try legacySharedKeychain.deleteItem(forKey: key.rawValue)
    }
  }
}
