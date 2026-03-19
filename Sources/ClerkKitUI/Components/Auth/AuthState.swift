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

    func normalized(emailOrUsernameEnabled: Bool, phoneNumberEnabled: Bool) -> Self {
      switch self {
      case .identifier where !emailOrUsernameEnabled:
        phoneNumberEnabled ? .phoneNumber : .automatic
      case .phoneNumber where !phoneNumberEnabled:
        emailOrUsernameEnabled ? .identifier : .automatic
      case .automatic, .identifier, .phoneNumber:
        self
      }
    }
  }

  enum InitialPersistenceBehavior: Equatable {
    case none
    case clearPrefill
    case storeIdentifier(String)
    case storePhoneNumber(String)
  }

  /// The authentication mode (signIn, signUp, or signInOrUp).
  let mode: AuthView.Mode
  let preferredStartField: PreferredStartField
  private let defaults: UserDefaults
  private let initialPersistenceBehavior: InitialPersistenceBehavior
  private let lastUsedAuthBehavior: AuthView.LastUsedAuthBehavior

  init(
    mode: AuthView.Mode = .signInOrUp,
    identifierPrefill: AuthView.IdentifierPrefill = .persisted,
    lastUsedAuthBehavior: AuthView.LastUsedAuthBehavior = .preserve,
    defaults: UserDefaults = .standard
  ) {
    self.mode = mode
    self.defaults = defaults
    self.lastUsedAuthBehavior = lastUsedAuthBehavior

    switch identifierPrefill {
    case .persisted:
      let persisted = AuthStartStorage.loadPrefillState(defaults: defaults)
      authStartIdentifier = persisted.identifier
      authStartPhoneNumber = persisted.phoneNumber
      preferredStartField = .automatic
      initialPersistenceBehavior = .none
    case .empty:
      authStartIdentifier = ""
      authStartPhoneNumber = ""
      preferredStartField = .automatic
      initialPersistenceBehavior = .clearPrefill
    case .identifier(let value):
      authStartIdentifier = value
      authStartPhoneNumber = ""
      preferredStartField = .identifier
      initialPersistenceBehavior = .storeIdentifier(value)
    case .phoneNumber(let value):
      authStartIdentifier = ""
      authStartPhoneNumber = value
      preferredStartField = .phoneNumber
      initialPersistenceBehavior = .storePhoneNumber(value)
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

  func applyInitialPersistenceIfNeeded() {
    if lastUsedAuthBehavior == .clear {
      LastUsedAuth.clearStoredIdentifierType(defaults: defaults)
    }

    switch initialPersistenceBehavior {
    case .none:
      break
    case .clearPrefill:
      AuthStartStorage.clearPrefillState(defaults: defaults)
    case .storeIdentifier(let value):
      AuthStartStorage.clearPrefillState(defaults: defaults)
      AuthStartStorage.storeIdentifier(value, defaults: defaults)
    case .storePhoneNumber(let value):
      AuthStartStorage.clearPrefillState(defaults: defaults)
      AuthStartStorage.storePhoneNumber(value, defaults: defaults)
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
