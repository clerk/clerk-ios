//
//  SessionUtils.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

enum SessionUtils {
  /// Determines if the current session changed between two client states.
  ///
  /// This function compares the current sessions from two client states
  /// and returns `true` if they differ (including nil transitions).
  ///
  /// - Parameters:
  ///   - previousClient: The previous client state, or `nil` if this is the first client.
  ///   - currentClient: The current client state, or `nil` if the client was cleared.
  /// - Returns: `true` if the current session changed, `false` otherwise.
  static func sessionChanged(previousClient: Client?, currentClient: Client?) -> Bool {
    let oldSession = previousClient?.currentSession
    let newSession = currentClient?.currentSession
    return oldSession != newSession
  }
}
