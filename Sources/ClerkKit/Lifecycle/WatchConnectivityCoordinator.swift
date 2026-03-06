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
/// - Syncing authentication state (deviceToken, Client, Environment) to watch app
/// - Handling lifecycle events (foreground sync)
@MainActor
final class WatchConnectivityCoordinator {
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

  /// Syncs authentication state to watch app.
  func sync() {
    watchConnectivitySync?.syncAll()
  }
}
