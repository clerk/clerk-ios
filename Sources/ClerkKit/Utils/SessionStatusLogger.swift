//
//  SessionStatusLogger.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Manages logging of session status changes, particularly for pending sessions.
///
/// This class handles logging when sessions become pending or change state,
/// providing helpful debug information to developers about session status.
@MainActor
final class SessionStatusLogger {
  /// Logs pending session status if the session state has changed.
  ///
  /// This method checks if logging is needed based on session state changes
  /// and logs appropriate messages when a session becomes pending or changes tasks.
  ///
  /// - Parameters:
  ///   - previousClient: The previous client state, or nil if this is the first client.
  ///   - currentClient: The current client state.
  func logPendingSessionStatusIfNeeded(previousClient: Client?, currentClient: Client) {
    guard shouldLogPendingSessionStatus(previousClient: previousClient, currentClient: currentClient) else {
      return
    }

    let tasksDescription: String
    if let sessionId = currentClient.lastActiveSessionId,
       let session = currentClient.sessions.first(where: { $0.id == sessionId }),
       let tasks = session.tasks,
       !tasks.isEmpty
    {
      let taskKeys = tasks.map(\.key).joined(separator: ", ")
      tasksDescription = " Remaining session tasks: [\(taskKeys)]."
    } else {
      tasksDescription = ""
    }

    let message = "Your session is currently pending. Complete the remaining session tasks to activate it.\(tasksDescription)"
    ClerkLogger.info(message)
  }

  /// Determines whether pending session status should be logged.
  ///
  /// Logging occurs when:
  /// - The session is pending
  /// - This is the first client (no previous client)
  /// - The session ID changed
  /// - The session status changed
  /// - The session tasks changed
  ///
  /// - Parameters:
  ///   - previousClient: The previous client state, or nil if this is the first client.
  ///   - currentClient: The current client state.
  /// - Returns: `true` if logging should occur, `false` otherwise.
  func shouldLogPendingSessionStatus(previousClient: Client?, currentClient: Client) -> Bool {
    guard let sessionId = currentClient.lastActiveSessionId,
          let session = currentClient.sessions.first(where: { $0.id == sessionId })
    else {
      return false
    }

    guard session.status == .pending else {
      return false
    }

    // Log if this is the first client or if there's no previous session
    guard let previousClient,
          let previousId = previousClient.lastActiveSessionId,
          let previousSession = previousClient.sessions.first(where: { $0.id == previousId })
    else {
      return true
    }

    // Log if session ID changed
    if previousSession.id != session.id {
      return true
    }

    // Log if session status changed
    if previousSession.status != session.status {
      return true
    }

    // Log if session tasks changed
    if (previousSession.tasks ?? []) != (session.tasks ?? []) {
      return true
    }

    return false
  }
}
