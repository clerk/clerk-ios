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
/// - Syncing authentication state (deviceToken, Client, Environment) to watch app
/// - Handling lifecycle events (foreground sync)
@MainActor
package final class WatchConnectivityCoordinator {
  /// Unified Watch Connectivity sync interface for both iOS and watchOS platforms.
  private let watchConnectivitySync: (any WatchConnectivitySyncing)?

  /// Creates a new watch connectivity coordinator.
  init() {
    // Create watch connectivity manager/receiver
    #if os(iOS)
    watchConnectivitySync = createWatchConnectivityManager()
    #elseif os(watchOS)
    watchConnectivitySync = WatchSyncReceiver()
    #else
    watchConnectivitySync = nil
    #endif
  }

  /// Starts the coordinator and begins listening for events.
  ///
  /// Registers async event listener for watch sync.
  /// Device token saving happens synchronously in the middleware.
  func start() {
    startEventListener()
  }

  /// Stops the coordinator and cleans up resources.
  func stop() {
    eventListenerTask?.cancel()
    eventListenerTask = nil
  }

  /// Syncs authentication state to watch app.
  func sync() {
    watchConnectivitySync?.syncAll()
  }

  /// Task that listens for auth events and handles watch sync.
  private var eventListenerTask: Task<Void, Never>?

  /// Starts listening for auth events and handling device token updates.
  ///
  /// When a device token is received:
  /// 1. Syncs to watch app
  /// Note: Device token saving happens synchronously in the middleware
  private func startEventListener() {
    eventListenerTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for await event in Clerk.shared.clerkEventEmitter.events {
        if case .deviceTokenReceived = event {
          // Sync to watch app
          sync()
        }
      }
    }
  }
}
