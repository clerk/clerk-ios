//
//  WatchConnectivityCoordinator.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Coordinates watch connectivity syncing for Clerk.
///
/// This class manages all watch connectivity concerns including:
/// - Listening for device token updates and saving them to keychain
/// - Syncing authentication state (deviceToken, Client, Environment) to watch app when enabled
/// - Handling lifecycle events (foreground sync)
@MainActor
package final class WatchConnectivityCoordinator {
  /// Unified Watch Connectivity sync interface for both iOS and watchOS platforms.
  private let watchConnectivitySync: (any WatchConnectivitySyncing)?

  /// Whether watch connectivity syncing is enabled.
  private let syncEnabled: Bool

  /// Creates a new watch connectivity coordinator.
  ///
  /// - Parameters:
  ///   - keychain: The keychain storage for device tokens and watch connectivity sync.
  ///   - enabled: Whether watch connectivity sync is enabled.
  init(keychain: any KeychainStorage, enabled: Bool) {
    self.syncEnabled = enabled

    // Create watch connectivity manager/receiver if enabled
    #if os(iOS)
    self.watchConnectivitySync = enabled
      ? createWatchConnectivityManager(keychain: keychain)
      : nil
    #elseif os(watchOS)
    self.watchConnectivitySync = enabled
      ? WatchSyncReceiver(keychain: keychain)
      : nil
    #else
    self.watchConnectivitySync = nil
    #endif
  }

  /// Starts the coordinator and begins listening for events.
  ///
  /// Registers async event listener for watch sync if enabled.
  /// Device token saving happens synchronously in the middleware.
  func start() {
    startEventListener()
  }

  /// Stops the coordinator and cleans up resources.
  func stop() {
    eventListenerTask?.cancel()
    eventListenerTask = nil
  }

  /// Syncs authentication state to watch app if watch connectivity is enabled.
  func sync() {
    watchConnectivitySync?.syncAll()
  }

  /// Task that listens for auth events and handles watch sync.
  private var eventListenerTask: Task<Void, Never>?

  /// Starts listening for auth events and handling device token updates.
  ///
  /// When a device token is received:
  /// 1. Syncs to watch app if watch connectivity is enabled
  /// Note: Device token saving happens synchronously in the middleware
  private func startEventListener() {
    guard syncEnabled else { return }

    eventListenerTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for await event in Clerk.shared.clerkEventEmitter.events {
        if case .deviceTokenReceived = event {
          // Sync to watch app if enabled
          self.sync()
        }
      }
    }
  }

}

