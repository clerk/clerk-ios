//
//  ClerkAccessibilityIdentifiers.swift
//  Clerk
//

#if os(iOS)

enum ClerkAccessibilityIdentifiers {
  enum Auth {
    enum Start {
      static let identifier = "clerk.auth.start.identifier"
      static let continueButton = "clerk.auth.start.continue"
    }

    enum SignIn {
      static let password = "clerk.auth.signIn.password"
      static let continueButton = "clerk.auth.signIn.continue"
    }

    enum SignUp {
      static let code = "clerk.auth.signUp.code"
      static let password = "clerk.auth.signUp.password"
      static let continueButton = "clerk.auth.signUp.continue"
    }

    enum SessionTask {
      enum SetupMfa {
        static let smsCode = "clerk.auth.sessionTask.setupMfa.smsCode"
        static let authenticatorApp = "clerk.auth.sessionTask.setupMfa.authenticatorApp"
      }

      enum Totp {
        static let secret = "clerk.auth.sessionTask.totp.secret"
        static let continueButton = "clerk.auth.sessionTask.totp.continue"
        static let code = "clerk.auth.sessionTask.totp.code"
      }

      enum BackupCodes {
        static let continueButton = "clerk.auth.sessionTask.backupCodes.continue"
      }
    }
  }
}

#endif
