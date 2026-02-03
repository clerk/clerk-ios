//
//  SessionUtils.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

extension Client {
  /// Returns the currently active session for this client.
  ///
  /// The active session is determined by finding the session in `activeSessions`
  /// that matches `lastActiveSessionId`.
  ///
  /// - Returns: The active session if one exists, otherwise `nil`.
  var activeSession: Session? {
    guard let sessionId = lastActiveSessionId else {
      return nil
    }
    return activeSessions.first(where: { $0.id == sessionId })
  }
}

enum SessionUtils {
  /// Determines if the signed-in session changed between two client states.
  ///
  /// This function compares the signed-in sessions from two client states
  /// and returns `true` if they differ (including nil transitions).
  ///
  /// - Parameters:
  ///   - previousClient: The previous client state, or `nil` if this is the first client.
  ///   - currentClient: The current client state, or `nil` if the client was cleared.
  ///   - treatPendingAsSignedOut: Whether pending sessions should be treated as signed-out.
  /// - Returns: `true` if the signed-in session changed, `false` otherwise.
  static func sessionChanged(
    previousClient: Client?,
    currentClient: Client?,
    treatPendingAsSignedOut: Bool
  ) -> Bool {
    let oldSession = previousClient?.signedInSession(
      treatPendingAsSignedOut: treatPendingAsSignedOut
    )
    let newSession = currentClient?.signedInSession(
      treatPendingAsSignedOut: treatPendingAsSignedOut
    )
    return oldSession != newSession
  }

  /// Returns the signed-in session from a client state.
  ///
  /// - Parameter client: The client to extract the signed-in session from, or `nil`.
  /// - Parameter treatPendingAsSignedOut: Whether pending sessions should be treated as signed-out.
  /// - Returns: The signed-in session if one exists, otherwise `nil`.
  static func signedInSession(from client: Client?, treatPendingAsSignedOut: Bool) -> Session? {
    client?.signedInSession(treatPendingAsSignedOut: treatPendingAsSignedOut)
  }
}
