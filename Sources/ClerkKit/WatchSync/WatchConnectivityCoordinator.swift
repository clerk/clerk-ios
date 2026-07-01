//
//  WatchConnectivityCoordinator.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Coordinates WatchConnectivity as a transport for Clerk auth state.
@MainActor
final class WatchConnectivityCoordinator: ClerkInternalStateChangeObserver {
  private var watchConnectivitySync: (any WatchConnectivitySyncing)?
  private var authGeneration: WatchSyncVersion = .initial
  private var isApplyingRemotePayload = false
  private var isRefreshScheduled = false

  private enum RemoteAuthUpdateDecision {
    case apply
    case refresh
    case ignore
  }

  init() {
    #if os(iOS)
    watchConnectivitySync = createWatchConnectivityManager(
      payloadHandler: { [weak self] payload in
        self?.apply(payload, from: .watch, to: Clerk.shared)
      },
      activationHandler: { [weak self] in
        self?.syncCurrentState(from: Clerk.shared)
      }
    )
    #elseif os(watchOS)
    watchConnectivitySync = WatchSyncReceiver(
      payloadHandler: { [weak self] payload in
        self?.apply(payload, from: .phone, to: Clerk.shared)
      },
      activationHandler: { [weak self] in
        self?.syncCurrentState(from: Clerk.shared)
      }
    )
    #else
    watchConnectivitySync = nil
    #endif
  }

  func handle(_ change: ClerkInternalStateChange, from clerk: Clerk) throws {
    switch change {
    case let .clientDidChange(previousClient, client):
      guard !isApplyingRemotePayload,
            shouldPublishLocalAuthChange(previousClient: previousClient, client: client, clerk: clerk)
      else {
        return
      }

      try persistAuthState(
        client == nil ? "cleared" : "set",
        version: nextAuthVersion(keychain: clerk.dependencies.keychain),
        keychain: clerk.dependencies.keychain
      )
      syncCurrentState(from: clerk)
    case .environmentDidChange:
      guard !isApplyingRemotePayload else { return }
      syncCurrentState(from: clerk)
    case let .deviceTokenDidChange(previousToken, token):
      if previousToken != token {
        try persistDeviceTokenState(
          "set",
          version: nextDeviceTokenVersion(keychain: clerk.dependencies.keychain),
          keychain: clerk.dependencies.keychain
        )
      }

      syncCurrentState(from: clerk)
    case .applicationDidEnterForeground:
      syncCurrentState(from: clerk)
    }
  }

  func syncCurrentState(from clerk: Clerk) {
    guard let watchConnectivitySync else { return }

    authGeneration = max(authGeneration, readAuthVersion(keychain: clerk.dependencies.keychain))
    let payload = WatchSyncPayload(
      clerk: clerk,
      keychain: clerk.dependencies.keychain,
      authGeneration: authGeneration
    )
    watchConnectivitySync.sync(payload)
  }

  func apply(_ payload: WatchSyncPayload, from source: WatchSyncSource, to clerk: Clerk) {
    let wasApplyingRemotePayload = isApplyingRemotePayload
    isApplyingRemotePayload = true
    defer { isApplyingRemotePayload = wasApplyingRemotePayload }

    applyDeviceTokenUpdate(payload.deviceTokenUpdate, from: source, to: clerk)

    if let environment = payload.environment {
      clerk.environment = environment
    }

    applyClientUpdate(payload.clientUpdate, from: source, to: clerk)
  }

  private func applyDeviceTokenUpdate(
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
        try keychain.set(deviceToken, forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
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

  private func applyClientUpdate(_ update: WatchSyncClientUpdate, from source: WatchSyncSource, to clerk: Clerk) {
    switch update {
    case .notIncluded:
      return
    case let .snapshot(client, incomingServerFetchDate, version):
      applyClient(
        client,
        incomingServerFetchDate: incomingServerFetchDate,
        incomingIsAuthoritative: source.incomingDeviceIsAuthoritative,
        incomingVersion: version,
        authState: "set",
        to: clerk
      )
    case let .cleared(incomingServerFetchDate, version):
      applyClient(
        nil,
        incomingServerFetchDate: incomingServerFetchDate,
        incomingIsAuthoritative: source.incomingDeviceIsAuthoritative,
        incomingVersion: version,
        authState: "cleared",
        to: clerk
      )
    }
  }

  private func applyClient(
    _ incoming: Client?,
    incomingServerFetchDate: Date?,
    incomingIsAuthoritative: Bool,
    incomingVersion: WatchSyncVersion?,
    authState: String,
    to clerk: Clerk
  ) {
    switch remoteAuthUpdateDecision(
      incomingServerFetchDate: incomingServerFetchDate,
      incomingVersion: incomingVersion,
      incomingIsAuthoritative: incomingIsAuthoritative,
      clerk: clerk
    ) {
    case .apply:
      break
    case .refresh:
      scheduleRefresh(for: clerk)
      return
    case .ignore:
      return
    }

    if incomingIsAuthoritative {
      if let incomingServerFetchDate {
        clerk.lastClientServerFetchDate = incomingServerFetchDate
      }
      noteAppliedAuthState(authState, version: incomingVersion, keychain: clerk.dependencies.keychain)
      clerk.client = incoming
      return
    }

    if let incoming, let incomingServerFetchDate, let lastClientServerFetchDate = clerk.lastClientServerFetchDate,
       incomingServerFetchDate > lastClientServerFetchDate
    {
      clerk.lastClientServerFetchDate = incomingServerFetchDate
      noteAppliedAuthState(authState, version: incomingVersion, keychain: clerk.dependencies.keychain)
      if incoming != clerk.client {
        clerk.client = incoming
      } else {
        clerk.cacheManager?.saveServerFetchDate(incomingServerFetchDate)
      }
      return
    }

    if clerk.client != nil || clerk.lastClientServerFetchDate != nil {
      scheduleRefresh(for: clerk)
      return
    }

    if let incoming {
      clerk.lastClientServerFetchDate = incomingServerFetchDate
      noteAppliedAuthState(authState, version: incomingVersion, keychain: clerk.dependencies.keychain)
      clerk.client = incoming
      scheduleRefresh(for: clerk)
    }
  }

  private func remoteAuthUpdateDecision(
    incomingServerFetchDate: Date?,
    incomingVersion: WatchSyncVersion?,
    incomingIsAuthoritative: Bool,
    clerk: Clerk
  ) -> RemoteAuthUpdateDecision {
    let currentVersion = max(authGeneration, readAuthVersion(keychain: clerk.dependencies.keychain))

    if let incomingServerFetchDate, let lastClientServerFetchDate = clerk.lastClientServerFetchDate,
       incomingServerFetchDate < lastClientServerFetchDate
    {
      return .ignore
    }

    if let incomingVersion {
      if incomingVersion < currentVersion {
        return shouldRefreshForNonAuthoritativeAuthConflict(
          incomingServerFetchDate: incomingServerFetchDate,
          incomingIsAuthoritative: incomingIsAuthoritative,
          clerk: clerk
        )
      }
    } else if currentVersion > .initial {
      return shouldRefreshForNonAuthoritativeAuthConflict(
        incomingServerFetchDate: incomingServerFetchDate,
        incomingIsAuthoritative: incomingIsAuthoritative,
        clerk: clerk
      )
    }

    return .apply
  }

  private func shouldRefreshForNonAuthoritativeAuthConflict(
    incomingServerFetchDate: Date?,
    incomingIsAuthoritative: Bool,
    clerk: Clerk
  ) -> RemoteAuthUpdateDecision {
    guard !incomingIsAuthoritative, let incomingServerFetchDate else {
      return .ignore
    }

    if let lastClientServerFetchDate = clerk.lastClientServerFetchDate {
      return incomingServerFetchDate > lastClientServerFetchDate ? .refresh : .ignore
    }

    return .refresh
  }

  private func shouldPublishLocalAuthChange(previousClient: Client?, client: Client?, clerk: Clerk) -> Bool {
    client != nil || previousClient != nil || clerk.lastClientServerFetchDate != nil
  }

  private func noteAppliedAuthState(
    _ state: String,
    version incomingVersion: WatchSyncVersion?,
    keychain: any KeychainStorage
  ) {
    guard let incomingVersion, incomingVersion >= readAuthVersion(keychain: keychain) else {
      return
    }

    authGeneration = incomingVersion
    do {
      try persistAuthState(state, version: incomingVersion, keychain: keychain)
    } catch {
      ClerkLogger.logError(error, message: "Failed to persist auth sync state")
    }
  }
}

extension WatchConnectivityCoordinator {
  private func shouldApplyDeviceTokenUpdate(
    version incomingVersion: WatchSyncVersion?,
    from source: WatchSyncSource,
    keychain: any KeychainStorage
  ) -> Bool {
    let currentVersion = readDeviceTokenVersion(keychain: keychain)
    let currentToken = try? keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    guard let incomingVersion else {
      return shouldApplyLegacyDeviceTokenUpdate(from: source, currentToken: currentToken, keychain: keychain)
    }

    if incomingVersion < currentVersion {
      return false
    }

    if incomingVersion == currentVersion, !source.incomingDeviceIsAuthoritative, currentToken != nil {
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

  private func nextDeviceTokenVersion(keychain: any KeychainStorage) -> WatchSyncVersion {
    readDeviceTokenVersion(keychain: keychain).next()
  }

  private func readAuthVersion(keychain: any KeychainStorage) -> WatchSyncVersion {
    guard let versionString = try? keychain.string(forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue),
          let version = Int(versionString)
    else {
      return .initial
    }

    return WatchSyncVersion(rawValue: version)
  }

  private func nextAuthVersion(keychain: any KeychainStorage) -> WatchSyncVersion {
    readAuthVersion(keychain: keychain).next()
  }

  private func persistAuthState(
    _ state: String,
    version: WatchSyncVersion,
    keychain: any KeychainStorage
  ) throws {
    authGeneration = version
    try keychain.set(state, forKey: ClerkKeychainKey.watchSyncAuthState.rawValue)
    try keychain.set(String(version.rawValue), forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue)
  }

  private func persistDeviceTokenState(
    _ state: String,
    version: WatchSyncVersion?,
    keychain: any KeychainStorage
  ) throws {
    let resolvedVersion = version ?? nextDeviceTokenVersion(keychain: keychain)
    try keychain.set(state, forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue)
    try keychain.set(String(resolvedVersion.rawValue), forKey: ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue)
  }

  private func markDeviceTokenSynced(keychain: any KeychainStorage) throws {
    try keychain.set("true", forKey: ClerkKeychainKey.watchSyncDeviceTokenSynced.rawValue)
  }

  private func scheduleRefresh(for clerk: Clerk) {
    guard !isRefreshScheduled else { return }
    isRefreshScheduled = true

    let task = clerk.scheduleManagedTask { [weak self, weak clerk] in
      do {
        try await clerk?.refreshClient()
      } catch is CancellationError {
        // Managed cleanup cancels this task when Clerk reconfigures or resets.
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh client after watch sync")
      }
      await self?.finishScheduledRefresh()
    }

    if task == nil {
      isRefreshScheduled = false
    }
  }

  private func finishScheduledRefresh() {
    isRefreshScheduled = false
  }
}
