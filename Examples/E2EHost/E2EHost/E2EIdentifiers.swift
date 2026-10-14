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
  }

  enum Home {
    static let customSignIn = "e2e.home.customSignIn"
  }

  enum CustomSignIn {
    static let phoneNumber = "verify.customSignIn.phoneNumber"
    static let sendCode = "verify.customSignIn.sendCode"
    static let code = "verify.customSignIn.code"
    static let verifyCode = "verify.customSignIn.verifyCode"
    static let error = "verify.customSignIn.error"
  }

  enum Launch {
    static let error = "e2e.launch.error"
  }
}
