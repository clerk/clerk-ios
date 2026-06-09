//
//  ClerkAccessibilityIdentifiers.swift
//  Clerk
//

#if os(iOS) || os(macOS)

enum ClerkAccessibilityIdentifiers {
  static let dismissButton = "clerk.dismissButton"

  enum UserButton {
    static let profileButton = "clerk.userButton.profile"
  }

  enum AccountSwitcher {
    static func sessionButton(userID: String) -> String {
      "clerk.accountSwitcher.session.\(userID)"
    }

    static let addAccountButton = "clerk.accountSwitcher.addAccount"
    static let signOutAllButton = "clerk.accountSwitcher.signOutAll"
    static let doneButton = "clerk.accountSwitcher.done"
  }

  enum UserProfile {
    static func currentUser(userID: String) -> String {
      "clerk.userProfile.currentUser.\(userID)"
    }

    enum Row {
      static let manageAccount = "clerk.userProfile.row.manageAccount"
      static let security = "clerk.userProfile.row.security"
      static let switchAccount = "clerk.userProfile.row.switchAccount"
      static let addAccount = "clerk.userProfile.row.addAccount"
      static let signOut = "clerk.userProfile.row.signOut"
    }

    enum Security {
      static let changePassword = "clerk.userProfile.security.changePassword"
      static let addMfa = "clerk.userProfile.security.addMfa"
      static let deleteAccount = "clerk.userProfile.security.deleteAccount"
    }

    enum ChangePassword {
      static let currentPassword = "clerk.userProfile.changePassword.currentPassword"
      static let nextButton = "clerk.userProfile.changePassword.next"
      static let newPassword = "clerk.userProfile.changePassword.newPassword"
      static let confirmPassword = "clerk.userProfile.changePassword.confirmPassword"
      static let saveButton = "clerk.userProfile.changePassword.save"
    }

    enum Phone {
      static let phoneNumber = "clerk.userProfile.phone.phoneNumber"
      static let continueButton = "clerk.userProfile.phone.continue"
    }

    enum Mfa {
      static let smsCode = "clerk.userProfile.mfa.smsCode"
      static let authenticatorApp = "clerk.userProfile.mfa.authenticatorApp"
      static let smsPhoneNumberRow = "clerk.userProfile.mfa.sms.phoneNumber"
      static let smsContinue = "clerk.userProfile.mfa.sms.continue"
      static let smsAddPhone = "clerk.userProfile.mfa.sms.addPhone"
      static let totpSecret = "clerk.userProfile.mfa.totp.secret"
      static let totpContinue = "clerk.userProfile.mfa.totp.continue"
      static let verificationCode = "clerk.userProfile.mfa.verificationCode"
    }

    enum BackupCodes {
      static let doneButton = "clerk.userProfile.backupCodes.done"
    }

    enum DeleteAccount {
      static let confirmation = "clerk.userProfile.deleteAccount.confirmation"
      static let confirmButton = "clerk.userProfile.deleteAccount.confirm"
    }
  }

  enum Auth {
    static func socialProviderButton(strategy: String) -> String {
      "clerk.auth.socialProvider.\(strategy)"
    }

    enum Start {
      static let identifier = "clerk.auth.start.identifier"
      static let phoneNumber = "clerk.auth.start.phoneNumber"
      static let continueButton = "clerk.auth.start.continue"
      static let trustedDeviceSignInButton = "clerk.auth.start.trustedDeviceSignIn"
      static let identifierSwitcherButton = "clerk.auth.start.identifierSwitcher"
    }

    enum SignIn {
      static let code = "clerk.auth.signIn.code"
      static let password = "clerk.auth.signIn.password"
      static let continueButton = "clerk.auth.signIn.continue"
      static let useAnotherMethodButton = "clerk.auth.signIn.useAnotherMethod"

      static func alternativeMethodButton(strategy: String) -> String {
        "clerk.auth.signIn.alternativeMethod.\(strategy)"
      }
    }

    enum SignUp {
      static let code = "clerk.auth.signUp.code"
      static let emailAddress = "clerk.auth.signUp.emailAddress"
      static let username = "clerk.auth.signUp.username"
      static let password = "clerk.auth.signUp.password"
      static let continueButton = "clerk.auth.signUp.continue"
      static let completeProfileFirstName = "clerk.auth.signUp.completeProfile.firstName"
      static let completeProfileLastName = "clerk.auth.signUp.completeProfile.lastName"
      static let completeProfileContinueButton = "clerk.auth.signUp.completeProfile.continue"
      static let legalAccepted = "clerk.auth.signUp.legalAccepted"
    }

    enum SessionTask {
      enum SetupMfa {
        static let smsCode = "clerk.auth.sessionTask.setupMfa.smsCode"
        static let authenticatorApp = "clerk.auth.sessionTask.setupMfa.authenticatorApp"
      }

      enum Sms {
        static let phoneNumber = "clerk.auth.sessionTask.sms.phoneNumber"
        static let continueButton = "clerk.auth.sessionTask.sms.continue"
        static let code = "clerk.auth.sessionTask.sms.code"
      }

      enum Totp {
        static let secret = "clerk.auth.sessionTask.totp.secret"
        static let continueButton = "clerk.auth.sessionTask.totp.continue"
        static let code = "clerk.auth.sessionTask.totp.code"
      }

      enum BackupCodes {
        static let continueButton = "clerk.auth.sessionTask.backupCodes.continue"
      }

      enum ResetPassword {
        static let newPassword = "clerk.auth.sessionTask.resetPassword.newPassword"
        static let confirmPassword = "clerk.auth.sessionTask.resetPassword.confirmPassword"
        static let submitButton = "clerk.auth.sessionTask.resetPassword.submit"
      }
    }
  }

  enum Organization {
    enum AccountList {
      static let createOrganizationButton = "clerk.organization.accountList.createOrganization"
      static let acceptedInvitationButton = "clerk.organization.accountList.invitation.accepted"
      static let invitationJoinButton = "clerk.organization.accountList.invitation.join"
      static let membershipButton = "clerk.organization.accountList.membership"
    }

    enum ProfileForm {
      static let name = "clerk.organization.profileForm.name"
      static let slug = "clerk.organization.profileForm.slug"
      static let submitButton = "clerk.organization.profileForm.submit"
    }
  }
}

#endif
