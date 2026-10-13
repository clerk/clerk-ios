//
//  E2EIdentifiers.swift
//  E2EHost
//

enum E2EIdentifiers {
  enum Auth {
    static let signIn = "e2e.auth.signIn"
    static let signInFullScreen = "e2e.auth.signInFullScreen"
    static let signedIn = "e2e.auth.signedIn"
    static let signedOut = "e2e.auth.signedOut"
    static let signOut = "e2e.auth.signOut"
    static let userId = "e2e.auth.userId"
    static let sessionId = "e2e.auth.sessionId"
    static let sessionActive = "e2e.auth.sessionActive"
    static let sessionPending = "e2e.auth.sessionPending"
    static let pendingTasks = "e2e.auth.pendingTasks"
    static let deleteAccount = "e2e.auth.deleteAccount"
  }

  enum Launch {
    static let error = "e2e.launch.error"
  }
}
