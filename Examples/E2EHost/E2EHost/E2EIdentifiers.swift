//
//  E2EIdentifiers.swift
//  E2EHost
//

enum E2EIdentifiers {
  enum Auth {
    static let signedIn = "e2e.auth.signedIn"
    static let signedOut = "e2e.auth.signedOut"
    static let sessionActive = "e2e.auth.sessionActive"
    static let sessionPending = "e2e.auth.sessionPending"
    static let sessionStatus = "e2e.auth.sessionStatus"
    static let pendingTasks = "e2e.auth.pendingTasks"
    static let userID = "e2e.auth.userID"
    static let cleanupComplete = "e2e.auth.cleanupComplete"
    static let e2eOAuthConnected = "e2e.auth.e2eOAuthConnected"
    static let connectE2EOAuthProvider = "e2e.auth.connectE2EOAuthProvider"
    static let signOut = "e2e.auth.signOut"
    static let deleteAccount = "e2e.auth.deleteAccount"
  }
}
