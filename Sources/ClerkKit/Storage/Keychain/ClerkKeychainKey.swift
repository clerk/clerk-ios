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

  /// Key for the last explicit sibling-app auth sync state.
  case sharedSessionSyncAuthState

  /// Key for detecting explicit sibling-app auth sync events.
  case sharedSessionSyncAuthVersion

  /// Key for detecting explicit sibling-app environment sync events.
  case sharedSessionSyncEnvironmentVersion

  /// When this device last cleared its Clerk storage. Watch sync rejects paired-device state older than this.
  case watchSyncClearedAt = "clerkWatchSyncClearedAt"

  /// Legacy watch auth sync state. Retained so clears remove it from existing installs.
  case watchSyncAuthState

  /// Legacy watch identity ordering metadata. Retained so clears remove it from existing installs.
  case watchSyncMetadata = "clerkWatchSyncMetadataV2"

  /// Legacy watch auth sync version. Retained so clears remove it from existing installs.
  case watchSyncAuthVersion

  /// Key for device authentication token received from the server.
  case clerkDeviceToken

  /// Key for the last explicit sibling-app device-token sync state.
  case sharedSessionSyncDeviceTokenState

  /// Key for detecting explicit sibling-app device-token sync events.
  case sharedSessionSyncDeviceTokenVersion

  /// Legacy watch device-token sync state. Retained so clears remove it from existing installs.
  case watchSyncDeviceTokenState

  /// Legacy watch device-token sync version. Retained so clears remove it from existing installs.
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
