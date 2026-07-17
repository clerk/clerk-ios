//
//  Clerk+SharedSessionSync.swift
//  Clerk
//

import Foundation

extension Clerk {
  /// Reloads persisted Clerk auth state from the shared Keychain envelope.
  ///
  /// Shared session sync must be enabled in ``Clerk/Options``.
  ///
  /// - Returns: `true` when the in-memory identity changed.
  @discardableResult
  public func reloadFromSharedStorage() async -> Bool {
    guard let sharedSessionSyncCoordinator else {
      ClerkLogger.error(
        "reloadFromSharedStorage() requires Clerk.Options.sharedSessionSync to be enabled."
      )
      return false
    }

    return sharedSessionSyncCoordinator.reloadFromSharedStorage(force: true, to: self)
  }
}
