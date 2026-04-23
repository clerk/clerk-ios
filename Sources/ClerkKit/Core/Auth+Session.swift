//
//  Auth+Session.swift
//  Clerk
//

import Foundation

extension Auth {
  /// Signs out the active user.
  ///
  /// - Parameter sessionId: An optional session ID to sign out from a specific session. If nil, signs out from all sessions.
  /// - Throws: An error if the sign-out process fails.
  public func signOut(sessionId: String? = nil) async throws {
    try await sessionService.signOut(sessionId: sessionId)
  }

  /// Sets the active session and optionally the active organization.
  ///
  /// - Parameters:
  ///   - sessionId: The session ID to set as active.
  ///   - organizationId: The organization ID to set as active in the current session. If nil, removes the active organization.
  /// - Throws: An error if setting the active session fails.
  public func setActive(sessionId: String, organizationId: String? = nil) async throws {
    try await sessionService.setActive(
      sessionId: sessionId,
      organizationId: organizationId
    )
  }

  /// Retrieves the user's session token for the given template or the default Clerk token.
  ///
  /// This method uses a cache so a network request will only be made if the token in memory is expired.
  /// The TTL for Clerk token is one minute.
  ///
  /// - Parameter options: Options for token retrieval. See `Session.GetTokenOptions` for details.
  /// - Returns: The session token string, or nil if no active session exists.
  /// - Throws: An error if token retrieval fails.
  @discardableResult
  public func getToken(_ options: Session.GetTokenOptions = .init()) async throws -> String? {
    guard let session = clerk.session else {
      return nil
    }

    return try await getToken(for: session, options: options)
  }

  /// Revokes the specified session.
  ///
  /// - Parameter session: The session to revoke.
  /// - Returns: The revoked session.
  /// - Throws: An error if revoking the session fails.
  @discardableResult
  public func revokeSession(_ session: Session) async throws -> Session {
    try await sessionService.revoke(
      sessionId: session.id,
      actingSessionId: clerk.session?.id
    )
  }

  @discardableResult
  func revoke(_ session: Session) async throws -> Session {
    try await sessionService.revoke(
      sessionId: session.id,
      actingSessionId: clerk.session?.id
    )
  }

  @discardableResult
  func getToken(
    for session: Session,
    options: Session.GetTokenOptions = .init()
  ) async throws -> String? {
    try await sessionTokenFetcher.getToken(session, options: options)?.jwt
  }
}
