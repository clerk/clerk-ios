//
//  AppLocalStateAdoption.swift
//  Clerk
//

import Foundation

/// Selects app-local storage the first time an app enables shared-session sync.
/// Only environment settings may be copied from ambiguous legacy shared storage;
/// App Attest identifiers and pending magic-link secrets must remain app-attributed.
///
/// The marker is kept after sync is disabled, so the app keeps reading its private state
/// from the same place.
struct AppLocalStateAdoption {
  static let markerValue = "1"

  /// Where the marker lives. SDK 1.5 stored it here, so existing adoptions are honored.
  let markerKeychain: any KeychainStorage
  let appLocal: any KeychainStorage
  let shared: any KeychainStorage
  /// The app's bundle-ID service before it selected a common sharing service.
  var previousAppLocal: (any KeychainStorage)?

  static func usesAppLocalStorage(in markerKeychain: any KeychainStorage) throws -> Bool {
    try markerKeychain.string(forKey: ClerkKeychainKey.appLocalStateAdopted.rawValue) == markerValue
      || hasLegacyIdentityAdoption(in: markerKeychain)
  }

  /// Only SDK 1.5's completed identity adoption makes the separate legacy credentials stale.
  /// Moving private state alone must not suppress identity recovery on the next launch.
  static func hasLegacyIdentityAdoption(in markerKeychain: any KeychainStorage) throws -> Bool {
    try markerKeychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue) == "2"
  }

  func adoptIfNeeded() throws {
    guard try !Self.usesAppLocalStorage(in: markerKeychain) else { return }
    try copyIfMissing(.cachedEnvironment, sources: [previousAppLocal, shared].compactMap { $0 }) {
      (try? JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: $0)) != nil
    }
    let privateSources = [previousAppLocal].compactMap { $0 }
    try copyIfMissing(.pendingMagicLinkFlow, sources: privateSources) {
      guard let flow = try? JSONDecoder.clerkDecoder.decode(PendingMagicLinkFlow.self, from: $0) else { return false }
      return flow.expiresAt > Date()
    }
    try copyIfMissing(.attestKeyId, sources: privateSources) {
      String(data: $0, encoding: .utf8).nilIfEmpty != nil
    }
    // A shared legacy value has no reliable app owner. Never adopt a sibling's
    // PKCE verifier or App Attest key identifier as this app's private state.
    try markerKeychain.set(Self.markerValue, forKey: ClerkKeychainKey.appLocalStateAdopted.rawValue)
  }

  private func copyIfMissing(_ key: ClerkKeychainKey, sources: [any KeychainStorage], isValid: (Data) -> Bool) throws {
    guard try appLocal.data(forKey: key.rawValue) == nil else { return }
    for source in sources {
      guard let data = try source.data(forKey: key.rawValue), isValid(data) else { continue }
      try appLocal.set(data, forKey: key.rawValue)
      return
    }
  }
}
