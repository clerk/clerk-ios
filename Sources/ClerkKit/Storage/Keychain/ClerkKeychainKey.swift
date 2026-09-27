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

  /// SDK 1.5 marker indicating completed identity and private-state adoption.
  case sharedSessionSyncAdopted = "clerkSharedSessionSyncAdoptedV2"

  /// Selects app-local private state independently of identity migration progress.
  case appLocalStateAdopted = "clerkAppLocalStateAdoptedV1"

  /// Prefix for the versioned identity record; the instance fingerprint completes its account.
  case identity = "clerkIdentityV4"

  /// Prefix for the app-local migration marker, also suffixed with the instance fingerprint.
  case identityMigrated = "clerkIdentityMigrationV4"

  /// Key for the last explicit sibling-app auth sync state.
  case sharedSessionSyncAuthState

  /// Key for detecting explicit sibling-app auth sync events.
  case sharedSessionSyncAuthVersion

  /// Key for detecting explicit sibling-app environment sync events.
  case sharedSessionSyncEnvironmentVersion

  /// How many Clerk storage clears this device and its paired device have seen. Watch sync rejects state from an older generation.
  case watchSyncClearGeneration = "clerkWatchSyncClearGeneration"

  /// Legacy watch auth sync state. Retained so clears remove it from existing installs.
  case watchSyncAuthState

  /// Legacy watch identity ordering metadata. Retained so clears remove it from existing installs.
  case watchSyncMetadata = "clerkWatchSyncMetadataV2"

  /// Legacy Watch auth version; also preserves its maximum ordering floor across clears.
  case watchSyncAuthVersion

  /// Key for device authentication token received from the server.
  case clerkDeviceToken

  /// Key for the last explicit sibling-app device-token sync state.
  case sharedSessionSyncDeviceTokenState

  /// Key for detecting explicit sibling-app device-token sync events.
  case sharedSessionSyncDeviceTokenVersion

  /// Legacy watch device-token sync state. Retained so clears remove it from existing installs.
  case watchSyncDeviceTokenState

  /// Legacy Watch device-token version, retained across clears for mixed-version pairs.
  case watchSyncDeviceTokenVersion

  /// Legacy watch device-token sync flag. Retained so clears remove it from existing installs.
  case watchSyncDeviceTokenSynced = "clerkDeviceTokenSynced"

  /// Key for App Attest key ID.
  case attestKeyId = "AttestKeyId"

  /// Key for the pending magic-link flow.
  case pendingMagicLinkFlow

  /// Key for biometric credential metadata.
  case biometricCredentials = "trustedDeviceCredentials"
}
