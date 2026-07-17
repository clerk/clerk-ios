//
//  WatchConnectivityCoordinator+DeviceTokenUpdates.swift
//  Clerk
//

import Foundation

extension WatchConnectivityCoordinator {
  func applyDeviceTokenUpdate(
    _ update: WatchSyncDeviceTokenUpdate,
    from source: WatchSyncSource,
    to clerk: Clerk,
    allowNonAuthoritativeUpdate: Bool = true
  ) {
    let keychain = clerk.dependencies.appLocalKeychain

    switch update {
    case .notIncluded:
      return
    case let .tokenSet(deviceToken, version):
      guard shouldApplyDeviceTokenUpdate(
        version: version,
        from: source,
        allowNonAuthoritativeUpdate: allowNonAuthoritativeUpdate,
        currentToken: clerk.deviceToken,
        keychain: keychain
      ) else {
        return
      }

      do {
        let previousToken = clerk.deviceToken
        let currentToken = try clerk.replaceStoredDeviceToken(deviceToken)
        if previousToken != currentToken {
          handleAppliedDeviceTokenChange(from: source, clerk: clerk)
        }
        try persistDeviceTokenState("set", version: version, keychain: keychain)
        try markDeviceTokenSynced(keychain: keychain)
        syncCurrentState(from: clerk)
      } catch {
        ClerkLogger.logError(error, message: "Failed to store deviceToken from \(source.sourceDescription)")
      }
    case let .tokenCleared(version):
      guard shouldApplyDeviceTokenUpdate(
        version: version,
        from: source,
        allowNonAuthoritativeUpdate: allowNonAuthoritativeUpdate,
        currentToken: clerk.deviceToken,
        keychain: keychain
      ) else {
        return
      }

      do {
        try clerk.replaceStoredDeviceToken(nil)
        try persistDeviceTokenState("cleared", version: version, keychain: keychain)
        try markDeviceTokenSynced(keychain: keychain)
        try persistAuthState(
          "cleared",
          version: max(version ?? .initial, nextAuthVersion(keychain: keychain)),
          keychain: keychain
        )
        handleAppliedDeviceTokenChange(from: source, clerk: clerk)
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
    allowNonAuthoritativeUpdate: Bool,
    currentToken: String?,
    keychain: any KeychainStorage
  ) -> Bool {
    let currentVersion = readDeviceTokenVersion(keychain: keychain)
    let currentState = try? keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue)

    if !source.incomingDeviceIsAuthoritative, !allowNonAuthoritativeUpdate {
      do {
        try markDeviceTokenSynced(keychain: keychain)
      } catch {
        ClerkLogger.logError(error, message: "Failed to store deviceToken sync state")
      }
      return false
    }

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
    let hasVersionedLocalState = readDeviceTokenVersion(keychain: keychain) > .initial
      || (try? keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue)) != nil

    if !source.incomingDeviceIsAuthoritative,
       hasVersionedLocalState || (!hasSyncedBefore && currentToken != nil)
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

  private func handleAppliedDeviceTokenChange(from source: WatchSyncSource, clerk: Clerk) {
    if source.incomingDeviceIsAuthoritative {
      clerk.clearCachedClientStateAfterDeviceTokenChange()
    } else {
      clerk.hardFenceClientResponses()
    }
  }
}
