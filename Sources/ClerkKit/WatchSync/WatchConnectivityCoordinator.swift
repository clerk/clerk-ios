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
  private(set) var refreshTask: Task<Void, Never>?
  private var refreshGeneration: ClientResponseGeneration?

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
    case .localStorageDidClear:
      cancelRefresh()
      sync(from: clerk)
    case .clientDidChange, .deviceTokenDidChange, .identityDidChange, .applicationDidEnterForeground:
      if let refreshGeneration, refreshGeneration != clerk.clientResponseGeneration {
        cancelRefresh()
      }
      sync(from: clerk)
    }
  }

  func sync(from clerk: Clerk) {
    guard isActive, let transport, clerk.identityController.canPublishIdentity else { return }
    do {
      let state = try WatchSyncState(of: clerk)
      let version = try WatchSyncLegacyPublication.version(
        for: state, store: clerk.dependencies.identityStore, legacyKeychain: clerk.dependencies.watchSyncKeychain
      )
      transport.send(WatchSyncPayload(
        state: state, environment: clerk.environment,
        legacyVersion: version.map { .init(token: $0, auth: $0) }
      ))
    } catch {
      ClerkLogger.logError(error, message: "Failed to prepare Clerk auth state for the paired device")
    }
  }

  func apply(_ payload: WatchSyncPayload, from source: WatchSyncSource, to clerk: Clerk) {
    guard isActive else { return }

    // The phone fetches its own environment, so only the phone's is worth adopting.
    if source == .phone, let environment = payload.environment, environment != clerk.environment {
      isApplyingRemoteEnvironment = true
      clerk.environment = environment
      isApplyingRemoteEnvironment = false
    }

    guard let received = payload.state else { return }
    let localSource: WatchSyncSource = source == .phone ? .watch : .phone
    do {
      try clerk.identityController.applyExternalTransition {
        let local = try WatchSyncState(of: clerk)
        var incoming = received
        var phoneOrdering: WatchSyncPhoneOrdering?
        var orderingChanged = false
        if source == .phone {
          var ordering = try clerk.identityController.watchPhoneOrdering(includeLegacy: payload.isLegacy)
          let previous = ordering
          guard let translated = try ordering.state(from: payload, replacing: local) else { return nil }
          incoming = translated
          phoneOrdering = ordering
          orderingChanged = ordering != previous
        } else if payload.isLegacy, incoming.isCleared {
          return nil // SDK 1.5 Watch-only clears were never requests to clear the phone.
        }
        guard incoming.supersedes(local, from: source) else {
          if orderingChanged {
            return try ClerkIdentityController.ExternalTransition(
              identity: ClerkIdentitySnapshot(state: local.client == nil ? .cleared : .present,
                                              deviceToken: local.deviceToken, client: local.client, serverDate: local.serverDate).validated(),
              fenceAllClientResponses: false, watchPhoneOrdering: phoneOrdering
            )
          }
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
          watchClearGeneration: incoming.clearGeneration,
          watchPhoneOrdering: phoneOrdering,
          recordsClear: incoming.clearGeneration > local.clearGeneration,
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
    cancelRefresh()
  }
}

extension WatchSyncState {
  /// The state this device reports to its counterpart.
  ///
  /// - Throws: When the clear generation cannot be read.
  @MainActor
  init(of clerk: Clerk) throws {
    let deviceToken = clerk.deviceToken
    try self.init(
      deviceToken: deviceToken,
      client: deviceToken == nil ? nil : clerk.authoritativeClient,
      serverDate: clerk.lastClientServerFetchDate,
      clearGeneration: WatchSyncClearMarker.generation(in: clerk.dependencies.watchSyncKeychain)
    )
  }
}

extension WatchConnectivityCoordinator {
  private func didAdopt(_ incoming: WatchSyncState, into clerk: Clerk) {
    if incoming.deviceToken != nil, incoming.client == nil {
      refreshClient(for: clerk)
    }
  }

  private func refreshClient(for clerk: Clerk) {
    guard isActive else { return }
    let generation = clerk.clientResponseGeneration
    guard refreshGeneration != generation else { return }
    cancelRefresh()
    refreshGeneration = generation
    refreshTask = clerk.scheduleManagedTask { [weak self, weak clerk] in
      do {
        try await clerk?.refreshClient()
      } catch is CancellationError {
        // Managed cleanup cancels this task when Clerk reconfigures or resets.
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh client after watch sync")
      }
      await self?.refreshDidFinish(generation: generation)
    }
    if refreshTask == nil { refreshGeneration = nil }
  }

  private func cancelRefresh() {
    refreshTask?.cancel()
    refreshTask = nil
    refreshGeneration = nil
  }

  private func refreshDidFinish(generation: ClientResponseGeneration) {
    // Cancellation need not finish immediately. An old task cannot release the
    // replacement task's ownership after a clear or a different phone identity.
    guard refreshGeneration == generation else { return }
    refreshTask = nil
    refreshGeneration = nil
  }
}

/// Persists the clear generation: how many clears this device and its counterpart have seen.
/// Paired-device state from before a clear carries a lower generation, so it cannot bring the
/// old identity back.
enum WatchSyncClearMarker {
  private static let key = ClerkKeychainKey.watchSyncClearGeneration.rawValue

  static func generation(in keychain: any KeychainStorage) throws -> Int {
    if let value = try keychain.string(forKey: key) {
      guard let generation = Int(value), generation >= 0 else { throw KeychainError.invalidStringEncoding }
      return generation
    }
    // SDK 1.5 Watch clears were local. Upgrading must not turn one into a new phone clear.
    #if os(watchOS)
    let generation = 0
    #else
    let generation = try legacyRecordIsCleared(in: keychain) ? 1 : 0
    #endif
    try keychain.set(String(generation), forKey: key)
    return generation
  }

  /// Records a clear on this device.
  static func record(in keychain: any KeychainStorage) throws {
    let (generation, overflow) = try generation(in: keychain).addingReportingOverflow(1)
    guard !overflow else { throw KeychainError.invalidStringEncoding }
    try keychain.set(String(generation), forKey: key)
  }

  /// Adopts a clear generation seen on the paired device.
  static func raise(to generation: Int, in keychain: any KeychainStorage) throws {
    guard generation >= 0 else { throw KeychainError.invalidStringEncoding }
    guard try generation > self.generation(in: keychain) else { return }
    try keychain.set(String(generation), forKey: key)
  }

  private static func legacyRecordIsCleared(in keychain: any KeychainStorage) throws -> Bool {
    if let data = try keychain.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue),
       let record = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
      return record["device_token_state"] as? String == "cleared"
        || record["auth_state"] as? String == "cleared"
    }
    return try keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue) == "cleared"
      || keychain.string(forKey: ClerkKeychainKey.watchSyncAuthState.rawValue) == "cleared"
  }
}
