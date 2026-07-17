//
//  WatchConnectivityCoordinator+DeviceTokenUpdates.swift
//  Clerk
//

import Foundation

extension WatchConnectivityCoordinator {
  enum DeviceTokenUpdateOutcome {
    case compatibleWithPairedClient
    case rejectedDifferentToken

    var allowsPairedClientUpdate: Bool {
      switch self {
      case .compatibleWithPairedClient:
        true
      case .rejectedDifferentToken:
        false
      }
    }
  }

  func applyDeviceTokenUpdate(
    _ update: WatchSyncDeviceTokenUpdate,
    from source: WatchSyncSource,
    to clerk: Clerk,
    allowNonAuthoritativeUpdate: Bool = true
  ) throws -> DeviceTokenUpdateOutcome {
    switch update {
    case .notIncluded:
      return .compatibleWithPairedClient
    case let .tokenSet(deviceToken, version):
      let deviceToken = deviceToken.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !deviceToken.isEmpty else {
        return try applyDeviceTokenUpdate(
          .tokenCleared(version: version),
          from: source,
          to: clerk,
          allowNonAuthoritativeUpdate: allowNonAuthoritativeUpdate
        )
      }

      return try applyTokenSet(
        deviceToken,
        version: version,
        from: source,
        to: clerk,
        allowNonAuthoritativeUpdate: allowNonAuthoritativeUpdate
      )
    case let .tokenCleared(version):
      return try applyTokenClear(
        version: version,
        from: source,
        to: clerk,
        allowNonAuthoritativeUpdate: allowNonAuthoritativeUpdate
      )
    }
  }

  private func applyTokenSet(
    _ deviceToken: String,
    version: WatchSyncVersion?,
    from source: WatchSyncSource,
    to clerk: Clerk,
    allowNonAuthoritativeUpdate: Bool
  ) throws -> DeviceTokenUpdateOutcome {
    let keychain = clerk.dependencies.watchSyncKeychain
    guard shouldApplyDeviceTokenUpdate(
      version: version,
      from: source,
      allowNonAuthoritativeUpdate: allowNonAuthoritativeUpdate,
      currentToken: clerk.deviceToken,
      keychain: keychain
    ) else {
      return rejectedUpdateOutcome(
        incomingToken: deviceToken,
        currentToken: clerk.deviceToken
      )
    }

    let previousToken = clerk.deviceToken
    let currentToken = try clerk.replaceStoredDeviceToken(deviceToken)
    if previousToken != currentToken {
      handleAppliedDeviceTokenChange(from: source, clerk: clerk)
    }

    do {
      try persistDeviceTokenState("set", version: version, keychain: keychain)
      try markDeviceTokenSynced(keychain: keychain)
      syncCurrentState(from: clerk)
    } catch {
      ClerkLogger.logError(error, message: "Failed to store deviceToken sync state")
    }

    return .compatibleWithPairedClient
  }

  private func applyTokenClear(
    version: WatchSyncVersion?,
    from source: WatchSyncSource,
    to clerk: Clerk,
    allowNonAuthoritativeUpdate: Bool
  ) throws -> DeviceTokenUpdateOutcome {
    let keychain = clerk.dependencies.watchSyncKeychain
    guard shouldApplyDeviceTokenUpdate(
      version: version,
      from: source,
      allowNonAuthoritativeUpdate: allowNonAuthoritativeUpdate,
      currentToken: clerk.deviceToken,
      keychain: keychain
    ) else {
      return rejectedUpdateOutcome(
        incomingToken: nil,
        currentToken: clerk.deviceToken
      )
    }

    try clerk.replaceStoredDeviceToken(nil)
    handleAppliedDeviceTokenChange(from: source, clerk: clerk)

    do {
      try persistDeviceTokenState("cleared", version: version, keychain: keychain)
      try markDeviceTokenSynced(keychain: keychain)
      try persistAuthState(
        "cleared",
        version: max(version ?? .initial, nextAuthVersion(keychain: keychain)),
        keychain: keychain
      )
      syncCurrentState(from: clerk)
    } catch {
      ClerkLogger.logError(error, message: "Failed to store cleared deviceToken sync state")
    }

    return .compatibleWithPairedClient
  }

  private func rejectedUpdateOutcome(
    incomingToken: String?,
    currentToken: String?
  ) -> DeviceTokenUpdateOutcome {
    incomingToken == currentToken
      ? .compatibleWithPairedClient
      : .rejectedDifferentToken
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
