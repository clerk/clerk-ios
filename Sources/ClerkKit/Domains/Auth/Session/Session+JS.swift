import ClerkSnapshots
import Foundation

extension Session {
  /// Marks this session as revoked. If this is the active session, the attempt to revoke it will fail. Users can revoke only their own sessions.
  @discardableResult @MainActor
  public func revoke() async throws -> Session {
    try await Clerk.js(
      .session(id: ClerkJSResourceID(id)),
      SessionWithActivitiesJSCall.revoke,
      as: Session.self
    )
  }

  /**
   Retrieves the user's session token for the given template or the default Clerk token.
   This method uses a cache so a network request will only be made if the token in memory is expired.
   The TTL for the Clerk token is one minute.

   - Returns: The JWT string, or nil if no active session exists.
   */
  @discardableResult @MainActor
  public func getToken(_ options: GetTokenOptions = .init()) async throws -> String? {
    _ = try Clerk.requireStableRuntime()
    return try await Clerk.js(
      .session(id: ClerkJSResourceID(id)),
      SessionJSCall.getToken(
        ClerkSnapshots.GetTokenOptions(skipCache: options.skipCache, template: options.template)
      ),
      as: String?.self
    )
  }
}
