//
//  ClerkKeychainKey.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Centralized enum for all Clerk keychain keys.
///
/// This enum provides a single source of truth for all keychain keys used by the Clerk SDK,
/// making it easier to maintain and iterate over all keys when needed (e.g., for clearing all data).
enum ClerkKeychainKey: String, CaseIterable, Sendable {
  /// Key for cached client data.
  case cachedClient

  /// Key for cached environment data.
  case cachedEnvironment

  /// Key for device authentication token received from the server.
  case clerkDeviceToken

  /// Key for tracking whether device token has been synced to watch app.
  case clerkDeviceTokenSynced

  /// Key for App Attest key ID.
  case attestKeyId = "AttestKeyId"
}
