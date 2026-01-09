//
//  AuthState.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

#if os(iOS)

import ClerkKit
import Foundation
import SwiftUI

/// Holds form field values for the authentication flow.
///
/// This class stores user input for auth start, sign-in, and sign-up forms.
@MainActor
@Observable
final class AuthState {
  /// The authentication mode (signIn, signUp, or signInOrUp).
  let mode: AuthView.Mode

  init(mode: AuthView.Mode = .signInOrUp) {
    self.mode = mode
  }

  // Auth Start Fields
  var authStartIdentifier: String = UserDefaults.standard.string(forKey: "authStartIdentifier") ?? "" {
    didSet {
      UserDefaults.standard.set(authStartIdentifier, forKey: "authStartIdentifier")
    }
  }

  var authStartPhoneNumber: String = UserDefaults.standard.string(forKey: "authStartPhoneNumber") ?? "" {
    didSet {
      UserDefaults.standard.set(authStartPhoneNumber, forKey: "authStartPhoneNumber")
    }
  }

  // Sign In Fields
  var signInPassword = ""
  var signInNewPassword = ""
  var signInConfirmNewPassword = ""
  var signInBackupCode = ""

  // Sign Up Fields
  var signUpFirstName = ""
  var signUpLastName = ""
  var signUpPassword = ""
  var signUpUsername = ""
  var signUpEmailAddress = ""
  var signUpPhoneNumber = ""
  var signUpLegalAccepted = false
}

#endif
