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
enum ClerkKeychainKey: String, CaseIterable {
  case cachedClient

  case cachedClientServerDate

  case cachedEnvironment

  case sharedSessionSyncAuthState

  case sharedSessionSyncAuthVersion

  case sharedSessionSyncEnvironmentVersion

  case watchSyncLastChange = "clerkWatchSyncLastChange"

  case clerkDeviceToken

  case sharedSessionSyncDeviceTokenState

  case sharedSessionSyncDeviceTokenVersion

  case attestKeyId = "AttestKeyId"

  case pendingMagicLinkFlow

  case biometricCredentials = "trustedDeviceCredentials"
}
