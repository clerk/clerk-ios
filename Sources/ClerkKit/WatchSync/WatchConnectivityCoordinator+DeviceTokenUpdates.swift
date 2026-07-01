//
//  WatchConnectivityCoordinator+DeviceTokenUpdates.swift
//  Clerk
//

import Foundation

extension WatchConnectivityCoordinator {
  func applyDeviceTokenUpdate(
    _ update: WatchSyncDeviceTokenUpdate,
    from source: WatchSyncSource,
    to clerk: Clerk
  ) {
    let keychain = clerk.dependencies.keychain

    switch update {
    case .notIncluded:
      return
    case let .tokenSet(deviceToken, version):
      guard shouldApplyDeviceTokenUpdate(version: version, from: source, keychain: keychain) else {
        return
      }

      do {
        let previousToken = try? keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
        try keychain.set(deviceToken, forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
        if previousToken != deviceToken {
          clerk.clearCachedClientStateAfterDeviceTokenChange()
        }
        try persistDeviceTokenState("set", version: version, keychain: keychain)
        try markDeviceTokenSynced(keychain: keychain)
        syncCurrentState(from: clerk)
      } catch {
        ClerkLogger.logError(error, message: "Failed to store deviceToken from \(source.sourceDescription)")
      }
    case let .tokenCleared(version):
      guard shouldApplyDeviceTokenUpdate(version: version, from: source, keychain: keychain) else {
        return
      }

      do {
        try keychain.deleteItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
        try persistDeviceTokenState("cleared", version: version, keychain: keychain)
        try markDeviceTokenSynced(keychain: keychain)
        try persistAuthState(
          "cleared",
          version: max(version ?? .initial, nextAuthVersion(keychain: keychain)),
          keychain: keychain
        )
        clerk.clearCachedClientStateAfterDeviceTokenChange()
        syncCurrentState(from: clerk)
      } catch {
        ClerkLogger.logError(error, message: "Failed to clear deviceToken from \(source.sourceDescription)")
      }
    }
  }

  func nextDeviceTokenVersion(keychain: any KeychainStorage) -> WatchSyncVersion {
    readDeviceTokenVersion(keychain: keychain).next()
  }

  func persistDeviceTokenState(
    _ state: String,
    version: WatchSyncVersion?,
    keychain: any KeychainStorage
  ) throws {
    let resolvedVersion = version ?? nextDeviceTokenVersion(keychain: keychain)
    try keychain.set(state, forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue)
    try keychain.set(String(resolvedVersion.rawValue), forKey: ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue)
  }

  private func shouldApplyDeviceTokenUpdate(
    version incomingVersion: WatchSyncVersion?,
    from source: WatchSyncSource,
    keychain: any KeychainStorage
  ) -> Bool {
    let currentVersion = readDeviceTokenVersion(keychain: keychain)
    let currentToken = try? keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let currentState = try? keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue)

    guard let incomingVersion else {
      return shouldApplyLegacyDeviceTokenUpdate(from: source, currentToken: currentToken, keychain: keychain)
    }

    if incomingVersion < currentVersion {
      return false
    }

    if incomingVersion == currentVersion,
       !source.incomingDeviceIsAuthoritative,
       currentToken != nil || currentState != nil
    {
      do {
        try markDeviceTokenSynced(keychain: keychain)
      } catch {
        ClerkLogger.logError(error, message: "Failed to store deviceToken sync state")
      }
      return false
    }

    return true
  }

  private func shouldApplyLegacyDeviceTokenUpdate(
    from source: WatchSyncSource,
    currentToken: String?,
    keychain: any KeychainStorage
  ) -> Bool {
    let hasSyncedBefore = (try? keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenSynced.rawValue)) == "true"

    if !hasSyncedBefore, currentToken != nil, !source.incomingDeviceIsAuthoritative {
      do {
        try markDeviceTokenSynced(keychain: keychain)
      } catch {
        ClerkLogger.logError(error, message: "Failed to store deviceToken sync state")
      }
      return false
    }

    return true
  }

  private func readDeviceTokenVersion(keychain: any KeychainStorage) -> WatchSyncVersion {
    guard let versionString = try? keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue),
          let version = Int(versionString)
    else {
      return .initial
    }

    return WatchSyncVersion(rawValue: version)
  }

  private func markDeviceTokenSynced(keychain: any KeychainStorage) throws {
    try keychain.set("true", forKey: ClerkKeychainKey.watchSyncDeviceTokenSynced.rawValue)
  }
}
