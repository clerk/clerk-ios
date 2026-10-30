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
    static let customReverify = "e2e.home.customReverify"
    static let organizationTabs = "e2e.home.organizationTabs"
  }

  enum CustomSignIn {
    static let phoneNumber = "verify.customSignIn.phoneNumber"
    static let sendCode = "verify.customSignIn.sendCode"
    static let code = "verify.customSignIn.code"
    static let verifyCode = "verify.customSignIn.verifyCode"
    static let error = "verify.customSignIn.error"
  }

  enum CustomReverify {
    static let sendCode = "verify.customReverify.sendCode"
    static let code = "verify.customReverify.code"
    static let newPassword = "verify.customReverify.newPassword"
    static let verify = "verify.customReverify.verify"
    static let error = "verify.customReverify.error"
  }

  enum Launch {
    static let error = "e2e.launch.error"
  }
}
