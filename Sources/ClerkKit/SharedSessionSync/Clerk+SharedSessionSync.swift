//
//  Clerk+SharedSessionSync.swift
//  Clerk
//

extension Clerk {
  /// Reloads the persisted Clerk identity and cached environment.
  ///
  /// Use this when another app or extension sharing the same Keychain access group
  /// may have changed the identity. With shared-session sync, Clerk also does this
  /// automatically when another app writes, when the app enters the foreground, and
  /// before each request.
  ///
  /// - Returns: `true` when any in-memory identity or environment value changed.
  @discardableResult
  public func reloadFromSharedStorage() async -> Bool {
    await identityController.reloadPersistedState()
  }
}
