//
//  Clerk+SharedSessionSync.swift
//  Clerk
//

extension Clerk {
  /// Reloads this app's persisted atomic or legacy Clerk state.
  ///
  /// When shared-session sync is enabled, this reconciles all compatible sibling
  /// owner slots. In app-local mode, it reloads the persisted identity directly.
  ///
  /// - Returns: `true` when any in-memory identity or environment value changed.
  @discardableResult
  public func reloadFromSharedStorage() async -> Bool {
    await identityController.reloadPersistedState()
  }
}
