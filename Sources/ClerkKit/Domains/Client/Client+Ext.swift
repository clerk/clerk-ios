//
//  Client+Ext.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

extension Client {
  var currentSession: Session? {
    guard let sessionId = lastActiveSessionId else {
      return nil
    }
    return sessions.first(where: { $0.id == sessionId })
  }
}
