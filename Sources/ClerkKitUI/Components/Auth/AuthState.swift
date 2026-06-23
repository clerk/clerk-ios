//
//  AuthState.swift
//  Clerk
//

#if os(iOS) || os(macOS)

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

  /// Whether the configure method received an initial identifier value.
  private(set) var hasInitialIdentifier: Bool = false

  /// Whether the non-phone auth-start identifier field was populated from configuration.
  private(set) var authStartIdentifierWasPrefilled: Bool = false

  /// Whether the phone auth-start identifier field was populated from configuration.
  private(set) var authStartPhoneNumberWasPrefilled: Bool = false

  /// Whether the configure method received an initial first name value.
  private(set) var hasInitialFirstName: Bool = false

  /// Whether the configure method received an initial last name value.
  private(set) var hasInitialLastName: Bool = false

  /// Whether configured initial values should be shown as read-only fields.
  private(set) var prefilledFieldsAreLocked = false

  /// Unsafe metadata to attach if the current UI flow creates a sign-up.
  private(set) var unsafeMetadata: JSON?

  private let userDefaults: UserDefaults

  init(
    mode: AuthView.Mode = .signInOrUp,
    config: AuthConfig = AuthConfig(),
    userDefaults: UserDefaults = .standard
  ) {
    self.mode = mode
    self.userDefaults = userDefaults
    authStartIdentifier = userDefaults.string(forKey: Self.identifierStorageKey) ?? ""
    authStartPhoneNumber = userDefaults.string(forKey: Self.phoneNumberStorageKey) ?? ""
    authStartPhoneNumberFieldIsActive = userDefaults.bool(forKey: Self.phoneNumberFieldIsActiveStorageKey)
    configure(config)
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

  var authStartPhoneNumberFieldIsActive = false {
    didSet {
      if persistsIdentifiers {
        userDefaults.set(authStartPhoneNumberFieldIsActive, forKey: Self.phoneNumberFieldIsActiveStorageKey)
      }
    }
  }

  /// Applies auth flow configuration values.
  func configure(_ config: AuthConfig) {
    persistsIdentifiers = config.persistsIdentifiers
    let initialIdentifier = config.initialIdentifier
    hasInitialIdentifier = initialIdentifier?.isEmptyTrimmed == false
    authStartPhoneNumberWasPrefilled = hasInitialIdentifier && initialIdentifier?.looksLikePhoneNumber == true
    authStartIdentifierWasPrefilled = hasInitialIdentifier && !authStartPhoneNumberWasPrefilled
    hasInitialFirstName = config.initialFirstName?.isEmptyTrimmed == false
    hasInitialLastName = config.initialLastName?.isEmptyTrimmed == false
    prefilledFieldsAreLocked = config.prefilledFieldsAreLocked
    unsafeMetadata = config.unsafeMetadata

    if !config.persistsIdentifiers {
      userDefaults.removeObject(forKey: Self.identifierStorageKey)
      userDefaults.removeObject(forKey: Self.phoneNumberStorageKey)
      userDefaults.removeObject(forKey: Self.phoneNumberFieldIsActiveStorageKey)
      LastUsedAuth.clearStoredIdentifierType(userDefaults: userDefaults)
    }

    if let identifier = config.initialIdentifier {
      if identifier.looksLikePhoneNumber {
        authStartPhoneNumberFieldIsActive = true
        authStartPhoneNumber = identifier
        authStartIdentifier = ""
      } else {
        authStartPhoneNumberFieldIsActive = false
        authStartIdentifier = identifier
        authStartPhoneNumber = ""
      }
    } else if !config.persistsIdentifiers {
      authStartIdentifier = ""
      authStartPhoneNumber = ""
      authStartPhoneNumberFieldIsActive = false
    }

    if let firstName = config.initialFirstName {
      signUpFirstName = firstName
    }

    if let lastName = config.initialLastName {
      signUpLastName = lastName
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
  var authStartIdentifierIsLocked: Bool {
    prefilledFieldsAreLocked && authStartIdentifierWasPrefilled && !authStartIdentifier.isEmptyTrimmed
  }

  var authStartPhoneNumberIsLocked: Bool {
    prefilledFieldsAreLocked && authStartPhoneNumberWasPrefilled && !authStartPhoneNumber.isEmptyTrimmed
  }

  func authStartIdentifierIsLocked(for factor: Factor) -> Bool {
    switch factor.strategy {
    case .phoneCode, .resetPasswordPhoneCode:
      authStartPhoneNumberIsLocked
    case .emailCode, .emailLink, .resetPasswordEmailCode:
      authStartIdentifierIsLocked
    case .password, .passkey:
      factor.phoneNumberId != nil || factor.safeIdentifier?.looksLikePhoneNumber == true
        ? authStartPhoneNumberIsLocked
        : authStartIdentifierIsLocked
    default:
      false
    }
  }

  var signUpFirstNameIsEnabled: Bool {
    !(prefilledFieldsAreLocked && hasInitialFirstName && !signUpFirstName.isEmptyTrimmed)
  }

  var signUpLastNameIsEnabled: Bool {
    !(prefilledFieldsAreLocked && hasInitialLastName && !signUpLastName.isEmptyTrimmed)
  }
}

extension AuthState {
  static let identifierStorageKey = "authStartIdentifier"
  static let phoneNumberStorageKey = "authStartPhoneNumber"
  static let phoneNumberFieldIsActiveStorageKey = "authStartPhoneNumberFieldIsActive"
}

#endif
