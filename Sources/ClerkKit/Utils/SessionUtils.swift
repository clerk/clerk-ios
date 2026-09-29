//
//  SessionUtils.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

enum SessionUtils {
  static func sessionChanged(previousClient: Client?, currentClient: Client?) -> Bool {
    let oldSession = previousClient?.currentSession
    let newSession = currentClient?.currentSession
    return oldSession != newSession
  }
}
