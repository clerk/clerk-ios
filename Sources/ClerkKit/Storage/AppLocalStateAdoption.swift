//
//  AppLocalStateAdoption.swift
//  Clerk
//

import Foundation

/// Moves app-private state out of the shared access group the first time an app enables
/// shared-session sync, so sibling apps never read each other's environment, App Attest
/// key, or pending magic link.
///
/// The marker is kept after sync is disabled, so the app keeps reading its private state
/// from the same place.
struct AppLocalStateAdoption {
  static let markerValue = "2"

  /// Where the marker lives. SDK 1.5 stored it here, so existing adoptions are honored.
  let markerKeychain: any KeychainStorage
  let appLocal: any KeychainStorage
  let shared: any KeychainStorage

  static func isAdopted(in markerKeychain: any KeychainStorage) throws -> Bool {
    try markerKeychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue) == markerValue
  }

  func adoptIfNeeded() throws {
    guard try !Self.isAdopted(in: markerKeychain) else { return }
    try copyIfMissing(.cachedEnvironment) {
      (try? JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: $0)) != nil
    }
    try copyIfMissing(.pendingMagicLinkFlow) {
      guard let flow = try? JSONDecoder.clerkDecoder.decode(PendingMagicLinkFlow.self, from: $0) else {
        return false
      }
      return flow.expiresAt > Date()
    }
    try copyIfMissing(.attestKeyId) {
      String(data: $0, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
    try markerKeychain.set(Self.markerValue, forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue)
  }

  private func copyIfMissing(_ key: ClerkKeychainKey, isValid: (Data) -> Bool) throws {
    guard try appLocal.data(forKey: key.rawValue) == nil,
          let data = try shared.data(forKey: key.rawValue),
          isValid(data)
    else {
      return
    }
    try appLocal.set(data, forKey: key.rawValue)
  }
}
