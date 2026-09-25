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

    // The phone fetches its own environment, so only the phone's is worth adopting.
    if source == .phone, let environment = payload.environment, environment != clerk.environment {
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
      clearGeneration: WatchSyncClearMarker.generation(in: clerk.dependencies.watchSyncKeychain)
    )
  }
}

extension WatchConnectivityCoordinator {
  private func didAdopt(_ incoming: WatchSyncState, into clerk: Clerk) {
    recordClearGeneration(incoming.clearGeneration, in: clerk)
    if incoming.deviceToken != nil, incoming.client == nil {
      refreshClient(for: clerk)
    }
  }

  private func recordClearGeneration(_ generation: Int, in clerk: Clerk) {
    do {
      try WatchSyncClearMarker.raise(to: generation, in: clerk.dependencies.watchSyncKeychain)
    } catch {
      ClerkLogger.logError(error, message: "Failed to record the paired device's Clerk clear")
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

/// Persists the clear generation: how many clears this device and its counterpart have seen.
/// Paired-device state from before a clear carries a lower generation, so it cannot bring the
/// old identity back.
enum WatchSyncClearMarker {
  private static let key = ClerkKeychainKey.watchSyncClearGeneration.rawValue

  static func generation(in keychain: any KeychainStorage) -> Int {
    if let value = try? keychain.string(forKey: key), let generation = Int(value) {
      return generation
    }
    // SDK 1.5 kept a clear tombstone in its Watch metadata; honor it once after upgrading.
    // A watch clear in SDK 1.5 did not sign out the phone, so only the phone imports it.
    #if os(watchOS)
    let generation = 0
    #else
    let generation = legacyRecordIsCleared(in: keychain) ? 1 : 0
    #endif
    try? keychain.set(String(generation), forKey: key)
    return generation
  }

  /// Records a clear on this device.
  static func record(in keychain: any KeychainStorage) throws {
    try keychain.set(String(generation(in: keychain) + 1), forKey: key)
  }

  /// Adopts a clear generation seen on the paired device.
  static func raise(to generation: Int, in keychain: any KeychainStorage) throws {
    guard generation > self.generation(in: keychain) else { return }
    try keychain.set(String(generation), forKey: key)
  }

  private static func legacyRecordIsCleared(in keychain: any KeychainStorage) -> Bool {
    if let data = try? keychain.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue),
       let record = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
      return record["device_token_state"] as? String == "cleared"
        || record["auth_state"] as? String == "cleared"
    }
    return (try? keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue)) == "cleared"
      || (try? keychain.string(forKey: ClerkKeychainKey.watchSyncAuthState.rawValue)) == "cleared"
  }
}
