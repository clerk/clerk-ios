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
  /// Determines if the active session changed between two client states.
  ///
  /// This function compares the active sessions from two client states
  /// and returns `true` if they differ (including nil transitions).
  ///
  /// - Parameters:
  ///   - previousClient: The previous client state, or `nil` if this is the first client.
  ///   - currentClient: The current client state, or `nil` if the client was cleared.
  /// - Returns: `true` if the active session changed, `false` otherwise.
  static func sessionChanged(previousClient: Client?, currentClient: Client?) -> Bool {
    let oldSession = previousClient?.activeSession
    let newSession = currentClient?.activeSession
    return oldSession != newSession
  }

  /// Returns the active session from a client state.
  ///
  /// - Parameter client: The client to extract the active session from, or `nil`.
  /// - Returns: The active session if one exists, otherwise `nil`.
  static func activeSession(from client: Client?) -> Session? {
    client?.activeSession
  }
}
