//
//  AuthState.swift
//  Clerk
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
  enum PreferredStartField: Equatable {
    case automatic
    case identifier
    case phoneNumber
  }

  /// The authentication mode (signIn, signUp, or signInOrUp).
  let mode: AuthView.Mode
  let preferredStartField: PreferredStartField
  private let defaults: UserDefaults

  init(
    mode: AuthView.Mode = .signInOrUp,
    identifierPrefill: AuthView.IdentifierPrefill = .persisted,
    defaults: UserDefaults = .standard
  ) {
    self.mode = mode
    self.defaults = defaults

    switch identifierPrefill {
    case .persisted:
      let persisted = AuthStartStorage.loadPrefillState(defaults: defaults)
      authStartIdentifier = persisted.identifier
      authStartPhoneNumber = persisted.phoneNumber
      preferredStartField = .automatic
    case .empty:
      AuthStartStorage.clearPrefillState(defaults: defaults)
      authStartIdentifier = ""
      authStartPhoneNumber = ""
      preferredStartField = .automatic
    case .identifier(let value):
      AuthStartStorage.clearPrefillState(defaults: defaults)
      AuthStartStorage.storeIdentifier(value, defaults: defaults)
      AuthStartStorage.storeIdentifierType(value.isEmailAddress ? "email" : "username", defaults: defaults)
      authStartIdentifier = value
      authStartPhoneNumber = ""
      preferredStartField = .identifier
    case .phoneNumber(let value):
      AuthStartStorage.clearPrefillState(defaults: defaults)
      AuthStartStorage.storePhoneNumber(value, defaults: defaults)
      AuthStartStorage.storeIdentifierType("phone", defaults: defaults)
      authStartIdentifier = ""
      authStartPhoneNumber = value
      preferredStartField = .phoneNumber
    }
  }

  /// Whether this UI flow should allow transfer from sign-in to sign-up.
  var transferable: Bool {
    switch mode {
    case .signIn:
      false
    case .signUp, .signInOrUp:
      true
    }
  }

  /// Auth Start Fields
  var authStartIdentifier: String {
    didSet {
      AuthStartStorage.storeIdentifier(authStartIdentifier, defaults: defaults)
    }
  }

  var authStartPhoneNumber: String {
    didSet {
      AuthStartStorage.storePhoneNumber(authStartPhoneNumber, defaults: defaults)
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
