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
