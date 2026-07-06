//
//  WatchConnectivityCoordinator+StatePersistence.swift
//  Clerk
//

import Foundation

extension WatchConnectivityCoordinator {
  func readAuthVersion(keychain: any KeychainStorage) -> WatchSyncVersion {
    guard let versionString = try? keychain.string(forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue),
          let version = Int(versionString)
    else {
      return .initial
    }

    return WatchSyncVersion(rawValue: version)
  }

  func nextAuthVersion(keychain: any KeychainStorage) -> WatchSyncVersion {
    readAuthVersion(keychain: keychain).next()
  }

  func persistAuthState(
    _ state: String,
    version: WatchSyncVersion,
    keychain: any KeychainStorage
  ) throws {
    setAuthGeneration(version)
    try keychain.set(state, forKey: ClerkKeychainKey.watchSyncAuthState.rawValue)
    try keychain.set(String(version.rawValue), forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue)
  }
}
