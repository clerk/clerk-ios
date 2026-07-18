//
//  Clerk+SharedSessionSync.swift
//  Clerk
//

extension Clerk {
  /// Reconciles this app's persisted identity with all compatible sibling owner slots.
  ///
  /// - Returns: `true` when the selected shared identity changed in memory.
  @discardableResult
  public func reloadFromSharedStorage() async -> Bool {
    guard let sharedSessionSyncCoordinator else {
      return false
    }
    return await sharedSessionSyncCoordinator.reloadFromSharedStorage()
  }
}
