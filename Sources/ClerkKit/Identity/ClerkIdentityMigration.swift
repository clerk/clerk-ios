//
//  ClerkIdentityMigration.swift
//  Clerk
//

import Foundation

/// Moves the device token and Client that earlier SDK versions stored as separate items into ``ClerkIdentityStore``.
struct ClerkIdentityMigration {
  static let legacyIdentityKeys: [ClerkKeychainKey] = [
    .clerkDeviceToken,
    .cachedClient,
    .cachedClientServerDate,
    .sharedSessionSyncAuthState,
    .sharedSessionSyncAuthVersion,
    .sharedSessionSyncEnvironmentVersion,
    .sharedSessionSyncDeviceTokenState,
    .sharedSessionSyncDeviceTokenVersion,
  ]

  let store: ClerkIdentityStore
  let legacyKeychain: any KeychainStorage

  func migrateIfNeeded() throws {
    guard let token = try legacyKeychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue).nilIfEmpty else {
      return
    }
    let client = try legacyKeychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue).flatMap {
      try? JSONDecoder.clerkDecoder.decode(Client.self, from: $0)
    }
    let serverDate = try legacyKeychain.string(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
      .flatMap(TimeInterval.init)
      .map(Date.init(timeIntervalSince1970:))
    let identity = try ClerkIdentitySnapshot(
      state: client == nil ? .cleared : .present,
      deviceToken: token,
      client: client,
      serverDate: serverDate
    ).validated()

    let existing: ClerkIdentitySnapshot?
    do {
      existing = try store.load()?.identity
    } catch ClerkIdentityStoreError.otherInstance {
      existing = nil
    }
    if existing == nil || (existing?.hasSession != true && identity.hasSession) {
      try store.save(identity)
    }

    for key in Self.legacyIdentityKeys {
      do {
        try legacyKeychain.deleteItem(forKey: key.rawValue)
      } catch {
        ClerkLogger.logError(error, message: "Failed to remove Clerk identity storage from an earlier SDK version")
      }
    }
  }
}

extension ClerkIdentitySnapshot {
  fileprivate var hasSession: Bool {
    client?.sessions.isEmpty == false
  }
}
