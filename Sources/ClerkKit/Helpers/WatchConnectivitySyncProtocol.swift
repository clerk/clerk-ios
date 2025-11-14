//
//  WatchConnectivitySyncProtocol.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Protocol for syncing authentication state (deviceToken, Client, Environment) between iOS and watchOS apps.
/// This protocol allows type-erasure for conditional compilation and provides a unified interface.
@MainActor
package protocol WatchConnectivitySyncing {
  func syncAll()
}
