//
//  WatchConnectivityCoordinator.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Keeps the phone and watch on the same Clerk auth state.
///
/// Each side sends its complete ``WatchSyncState`` whenever it changes. The receiver
/// adopts it when ``WatchSyncState/supersedes(_:from:)`` says it should, and otherwise
/// replies with its own state when that state would win on the other side.
@MainActor
final class WatchConnectivityCoordinator: ClerkInternalStateChangeObserver {
  private var transport: (any WatchSyncTransport)?
  private var isActive = true
  private var isApplyingRemoteEnvironment = false
  private var refreshTask: Task<Void, Never>?

  /// - Parameter transport: Overrides the platform WatchConnectivity transport.
  init(transport: (any WatchSyncTransport)? = nil) {
    self.transport = transport ?? makePlatformWatchSyncTransport(
      onReceive: { [weak self] payload, source in
        self?.apply(payload, from: source, to: Clerk.shared)
      },
      onActivate: { [weak self] in
        self?.sync(from: Clerk.shared)
      }
    )
  }

  func handle(_ change: ClerkInternalStateChange, from clerk: Clerk) throws {
    switch change {
    case .environmentDidChange:
      guard !isApplyingRemoteEnvironment else { return }
      sync(from: clerk)
    case .clientDidChange, .deviceTokenDidChange, .identityDidChange,
         .localStorageDidClear, .applicationDidEnterForeground:
      sync(from: clerk)
    }
  }

  func sync(from clerk: Clerk) {
    guard isActive else { return }
    transport?.send(WatchSyncPayload(state: WatchSyncState(of: clerk), environment: clerk.environment))
  }

  func apply(_ payload: WatchSyncPayload, from source: WatchSyncSource, to clerk: Clerk) {
    guard isActive else { return }

    if let environment = payload.environment, environment != clerk.environment {
      isApplyingRemoteEnvironment = true
      clerk.environment = environment
      isApplyingRemoteEnvironment = false
    }

    guard let incoming = payload.state else { return }
    let localSource: WatchSyncSource = source == .phone ? .watch : .phone
    do {
      try clerk.identityController.applyExternalTransition {
        let local = WatchSyncState(of: clerk)
        guard incoming.supersedes(local, from: source) else {
          if local.supersedes(incoming, from: localSource) {
            sync(from: clerk)
          }
          return nil
        }

        return try ClerkIdentityController.ExternalTransition(
          identity: ClerkIdentitySnapshot(
            state: incoming.client == nil ? .cleared : .present,
            deviceToken: incoming.deviceToken,
            client: incoming.client,
            serverDate: incoming.serverDate
          ).validated(),
          didApply: { [weak self, weak clerk] in
            guard let self, let clerk else { return }
            didAdopt(incoming, into: clerk)
          }
        )
      }
    } catch {
      ClerkLogger.logError(error, message: "Failed to apply Clerk auth state from the paired device")
    }
  }

  func stopAcceptingIdentityUpdates() {
    isActive = false
    refreshTask?.cancel()
    refreshTask = nil
  }
}

extension WatchSyncState {
  /// The state this device reports to its counterpart.
  @MainActor
  init(of clerk: Clerk) {
    let deviceToken = clerk.deviceToken
    self.init(
      deviceToken: deviceToken,
      client: deviceToken == nil ? nil : clerk.authoritativeClient,
      serverDate: clerk.lastClientServerFetchDate,
      clearedAt: WatchSyncClearMarker.load(from: clerk.dependencies.watchSyncKeychain)
    )
  }
}

extension WatchConnectivityCoordinator {
  private func didAdopt(_ incoming: WatchSyncState, into clerk: Clerk) {
    if incoming.isCleared, let clearedAt = incoming.clearedAt {
      do {
        try WatchSyncClearMarker.record(clearedAt, in: clerk.dependencies.watchSyncKeychain)
      } catch {
        ClerkLogger.logError(error, message: "Failed to record the paired device's Clerk clear")
      }
    }
    if incoming.deviceToken != nil, incoming.client == nil {
      refreshClient(for: clerk)
    }
  }

  private func refreshClient(for clerk: Clerk) {
    guard isActive, refreshTask == nil else { return }
    refreshTask = clerk.scheduleManagedTask { [weak self, weak clerk] in
      do {
        try await clerk?.refreshClient()
      } catch is CancellationError {
        // Managed cleanup cancels this task when Clerk reconfigures or resets.
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh client after watch sync")
      }
      await self?.refreshDidFinish()
    }
  }

  private func refreshDidFinish() {
    refreshTask = nil
  }
}

/// Persists when this device last cleared its Clerk storage, so paired-device
/// state from before the clear cannot bring the old identity back.
enum WatchSyncClearMarker {
  static func load(from keychain: any KeychainStorage) -> Date? {
    guard let value = try? keychain.string(forKey: ClerkKeychainKey.watchSyncClearedAt.rawValue),
          let interval = TimeInterval(value)
    else {
      return nil
    }
    return Date(timeIntervalSince1970: interval)
  }

  static func record(_ date: Date = Date(), in keychain: any KeychainStorage) throws {
    let clearedAt = max(date, load(from: keychain) ?? .distantPast)
    try keychain.set(
      String(clearedAt.timeIntervalSince1970),
      forKey: ClerkKeychainKey.watchSyncClearedAt.rawValue
    )
  }
}
