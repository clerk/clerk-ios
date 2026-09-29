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
  /// Key for cached client data.
  case cachedClient

  /// Key for the server timestamp from the response that last updated the cached client.
  case cachedClientServerDate

  /// Key for cached environment data.
  case cachedEnvironment

  /// Key indicating that this app adopted stable app-local shared-session persistence.
  case sharedSessionSyncAdopted = "clerkSharedSessionSyncAdoptedV2"

  case identity = "clerkIdentityV3"

  case identityMigrated = "clerkIdentityMigrationV3"

  /// Key for the last explicit sibling-app auth sync state.
  case sharedSessionSyncAuthState

  /// Key for detecting explicit sibling-app auth sync events.
  case sharedSessionSyncAuthVersion

  /// Key for detecting explicit sibling-app environment sync events.
  case sharedSessionSyncEnvironmentVersion

  case watchSyncClearGeneration = "clerkWatchSyncClearGeneration"

  case watchSyncAuthState

  case watchSyncMetadata = "clerkWatchSyncMetadataV2"

  case watchSyncAuthVersion

  /// Key for device authentication token received from the server.
  case clerkDeviceToken

  /// Key for the last explicit sibling-app device-token sync state.
  case sharedSessionSyncDeviceTokenState

  /// Key for detecting explicit sibling-app device-token sync events.
  case sharedSessionSyncDeviceTokenVersion

  case watchSyncDeviceTokenState

  case watchSyncDeviceTokenVersion

  case watchSyncDeviceTokenSynced = "clerkDeviceTokenSynced"

  /// Key for App Attest key ID.
  case attestKeyId = "AttestKeyId"

  /// Key for the pending magic-link flow.
  case pendingMagicLinkFlow

  /// Key for biometric credential metadata.
  case biometricCredentials = "trustedDeviceCredentials"
}
