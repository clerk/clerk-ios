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
        version: nextAuthVersion(keychain: clerk.dependencies.watchSyncKeychain),
        keychain: clerk.dependencies.watchSyncKeychain
      )
      syncCurrentState(from: clerk)
    case .environmentDidChange:
      guard !isApplyingRemotePayload else { return }
      syncCurrentState(from: clerk)
    case let .deviceTokenDidChange(previousToken, token):
      if previousToken != token {
        try persistDeviceTokenState(
          token == nil ? "cleared" : "set",
          version: nextDeviceTokenVersion(keychain: clerk.dependencies.watchSyncKeychain),
          keychain: clerk.dependencies.watchSyncKeychain
        )
      }

      syncCurrentState(from: clerk)
    case .applicationDidEnterForeground:
      syncCurrentState(from: clerk)
    }
  }

  func syncCurrentState(from clerk: Clerk) {
    guard let watchConnectivitySync else { return }

    let keychain = clerk.dependencies.watchSyncKeychain
    authGeneration = max(authGeneration, readAuthVersion(keychain: keychain))
    let payload = WatchSyncPayload(
      clerk: clerk,
      keychain: keychain,
      authGeneration: authGeneration
    )
    watchConnectivitySync.sync(payload)
  }

  func apply(_ payload: WatchSyncPayload, from source: WatchSyncSource, to clerk: Clerk) {
    let wasApplyingRemotePayload = isApplyingRemotePayload
    isApplyingRemotePayload = true
    defer { isApplyingRemotePayload = wasApplyingRemotePayload }
    let previousDeviceToken = clerk.deviceToken
    let previousClient = clerk.client
    let previousServerFetchDate = clerk.lastClientServerFetchDate

    let applyUpdates = { [self] in
      let shouldApplyPairedClientUpdate: Bool
      do {
        shouldApplyPairedClientUpdate = try applyDeviceTokenUpdate(
          payload.deviceTokenUpdate,
          from: source,
          to: clerk,
          allowNonAuthoritativeUpdate: shouldApplyNonAuthoritativeDeviceTokenUpdate(
            matching: payload.clientUpdate,
            from: source,
            to: clerk
          )
        ).allowsPairedClientUpdate
      } catch {
        shouldApplyPairedClientUpdate = false
        ClerkLogger.logError(error, message: "Failed to store deviceToken from \(source.sourceDescription)")
      }

      if let environment = payload.environment {
        clerk.environment = environment
      }

      if shouldApplyPairedClientUpdate {
        applyClientUpdate(payload.clientUpdate, from: source, to: clerk)
      }
    }

    if let coordinator = clerk.sharedSessionSyncCoordinator {
      coordinator.withDeferredPersistence(applyUpdates)
      let didChangeIdentity = previousDeviceToken != clerk.deviceToken
        || previousClient != clerk.client
        || previousServerFetchDate != clerk.lastClientServerFetchDate
      if didChangeIdentity {
        do {
          try coordinator.persistCurrentIdentityIfNeeded()
        } catch {
          ClerkLogger.logError(error, message: "Failed to persist auth state from \(source.sourceDescription)")
        }
      }
    } else {
      applyUpdates()
    }
  }

  private func shouldApplyNonAuthoritativeDeviceTokenUpdate(
    matching clientUpdate: WatchSyncClientUpdate,
    from source: WatchSyncSource,
    to clerk: Clerk
  ) -> Bool {
    guard !source.incomingDeviceIsAuthoritative else {
      return true
    }

    if willApplyClientUpdate(clientUpdate, from: source, to: clerk) {
      return true
    }

    if case .notIncluded = clientUpdate {
      return clerk.client == nil && clerk.lastClientServerFetchDate == nil
    }

    return false
  }

  func currentAuthVersion(keychain: any KeychainStorage) -> WatchSyncVersion {
    max(authGeneration, readAuthVersion(keychain: keychain))
  }

  func setAuthGeneration(_ version: WatchSyncVersion) {
    authGeneration = version
  }

  func markRefreshScheduled() -> Bool {
    guard !isRefreshScheduled else { return false }
    isRefreshScheduled = true
    return true
  }

  func clearRefreshScheduled() {
    isRefreshScheduled = false
  }
}
