//
//  Client+Ext.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

extension Client {
  /// Returns the current session for this client.
  ///
  /// The current session is determined by finding the session in `sessions`
  /// that matches `lastActiveSessionId`, regardless of status.
  ///
  /// - Returns: The current session if one exists, otherwise `nil`.
  var currentSession: Session? {
    guard let sessionId = lastActiveSessionId else {
      return nil
    }
    return sessions.first(where: { $0.id == sessionId })
  }
}
