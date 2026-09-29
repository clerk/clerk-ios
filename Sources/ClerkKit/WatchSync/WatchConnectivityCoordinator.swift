//
//  WatchConnectivityCoordinator.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Keeps the phone and watch signed in as the same user by exchanging ``WatchSyncChange``s.
@MainActor
final class WatchConnectivityCoordinator: ClerkInternalStateChangeObserver {
  private var transport: (any WatchSyncTransport)?
  private var isActive = true
  private var refreshTask: Task<Void, Never>?

  init(transport: (any WatchSyncTransport)? = nil) {
    self.transport = transport ?? makePlatformWatchSyncTransport(
      onReceive: { [weak self] change in
        self?.apply(change, to: Clerk.shared)
      },
      onActivate: { [weak self] in
        self?.resendLastChange(from: Clerk.shared)
      }
    )
  }

  func handle(_ change: ClerkInternalStateChange, from clerk: Clerk) throws {
    switch change {
    case .clientDidChange, .deviceTokenDidChange, .identityDidChange, .localStorageDidClear:
      recordLocalChange(in: clerk)
    case .environmentDidChange, .applicationDidEnterForeground:
      break
    }
  }

  func apply(_ incoming: WatchSyncChange, to clerk: Clerk) {
    let previous = lastChange(in: clerk)
    guard isActive, incoming.changedAt > (previous?.changedAt ?? .distantPast) else { return }
    save(incoming, in: clerk)
    do {
      if let token = incoming.deviceToken {
        try clerk.identityController.adoptDeviceToken(token)
        refreshClient(for: clerk)
      } else if signedInToken(of: clerk) != .some(nil) {
        try clerk.identityController.adoptDeviceToken(nil)
      }
    } catch {
      save(previous, in: clerk)
      ClerkLogger.logError(error, message: "Failed to apply the paired device's sign-in state")
    }
  }

  func stopAcceptingIdentityUpdates() {
    isActive = false
    refreshTask?.cancel()
    refreshTask = nil
  }

  private func recordLocalChange(in clerk: Clerk) {
    guard isActive, let current = signedInToken(of: clerk) else { return }
    let last = lastChange(in: clerk)
    guard current != last?.deviceToken else { return }
    // A sign-out is the signed-in Client losing its sessions, or a clear. Landing on a different
    // Client means the paired device rotated the token, and its newer change is on the way.
    guard current != nil || clerk.deviceToken == nil || clerk.client?.id == last?.clientId else { return }
    let change = WatchSyncChange(
      deviceToken: current,
      clientId: current == nil ? nil : clerk.client?.id,
      changedAt: Date()
    )
    save(change, in: clerk)
    transport?.send(change)
  }

  private func resendLastChange(from clerk: Clerk) {
    guard isActive, let change = lastChange(in: clerk) else { return }
    transport?.send(change)
  }

  /// The device token while signed in, `.some(nil)` while signed out, and `nil` while the Client
  /// for a token is still being fetched.
  private func signedInToken(of clerk: Clerk) -> String?? {
    guard let token = clerk.deviceToken else { return .some(nil) }
    guard let client = clerk.client else { return nil }
    return .some(client.sessions.isEmpty ? nil : token)
  }

  private func lastChange(in clerk: Clerk) -> WatchSyncChange? {
    do {
      return try clerk.dependencies.watchSyncKeychain.data(forKey: ClerkKeychainKey.watchSyncLastChange.rawValue)
        .map { try JSONDecoder.clerkDecoder.decode(WatchSyncChange.self, from: $0) }
    } catch {
      ClerkLogger.logError(error, message: "Failed to read the last Watch sync change")
      return nil
    }
  }

  private func save(_ change: WatchSyncChange?, in clerk: Clerk) {
    let key = ClerkKeychainKey.watchSyncLastChange.rawValue
    do {
      if let change {
        try clerk.dependencies.watchSyncKeychain.set(JSONEncoder.clerkEncoder.encode(change), forKey: key)
      } else {
        try clerk.dependencies.watchSyncKeychain.deleteItem(forKey: key)
      }
    } catch {
      ClerkLogger.logError(error, message: "Failed to save the last Watch sync change")
    }
  }

  private func refreshClient(for clerk: Clerk) {
    guard isActive, refreshTask == nil else { return }
    refreshTask = clerk.scheduleManagedTask { [weak self, weak clerk] in
      do {
        try await clerk?.refreshClient()
      } catch is CancellationError {
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh the client after Watch sync")
      }
      await self?.refreshDidFinish()
    }
  }

  private func refreshDidFinish() {
    refreshTask = nil
  }
}
