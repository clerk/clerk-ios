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
  /// The authentication mode (signIn, signUp, or signInOrUp).
  let mode: AuthView.Mode

  /// Whether identifier values are persisted to `UserDefaults` between sessions.
  private(set) var persistsIdentifiers: Bool = true

  /// Whether the configure method received any initial values.
  private(set) var hasInitialValues: Bool = false

  private let userDefaults: UserDefaults

  init(mode: AuthView.Mode = .signInOrUp, userDefaults: UserDefaults = .standard) {
    self.mode = mode
    self.userDefaults = userDefaults
    authStartIdentifier = userDefaults.string(forKey: Self.identifierStorageKey) ?? ""
    authStartPhoneNumber = userDefaults.string(forKey: Self.phoneNumberStorageKey) ?? ""
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
  var authStartIdentifier = "" {
    didSet {
      if persistsIdentifiers {
        userDefaults.set(authStartIdentifier, forKey: Self.identifierStorageKey)
      }
    }
  }

  var authStartPhoneNumber = "" {
    didSet {
      if persistsIdentifiers {
        userDefaults.set(authStartPhoneNumber, forKey: Self.phoneNumberStorageKey)
      }
    }
  }

  /// Applies identifier configuration values.
  func configure(_ config: AuthIdentifierConfig) {
    persistsIdentifiers = config.persistsIdentifiers
    hasInitialValues = config.initialIdentifier != nil

    if !config.persistsIdentifiers {
      userDefaults.removeObject(forKey: Self.identifierStorageKey)
      userDefaults.removeObject(forKey: Self.phoneNumberStorageKey)
      LastUsedAuth.clearStoredIdentifierType(userDefaults: userDefaults)
    }

    if let identifier = config.initialIdentifier {
      if identifier.looksLikePhoneNumber {
        authStartPhoneNumber = identifier
        authStartIdentifier = ""
      } else {
        authStartIdentifier = identifier
        authStartPhoneNumber = ""
      }
    } else if !config.persistsIdentifiers {
      authStartIdentifier = ""
      authStartPhoneNumber = ""
    }
  }

  func storeLastUsedIdentifierType(_ identifierType: LastUsedAuth) {
    guard persistsIdentifiers else { return }
    LastUsedAuth.storeIdentifierType(identifierType, userDefaults: userDefaults)
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

extension AuthState {
  static let identifierStorageKey = "authStartIdentifier"
  static let phoneNumberStorageKey = "authStartPhoneNumber"
}

#endif
