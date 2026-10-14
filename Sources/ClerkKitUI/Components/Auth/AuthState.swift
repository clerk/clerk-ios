//
//  AuthState.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation
import SwiftUI

@MainActor
@Observable
final class AuthState {
  let mode: AuthView.Mode

  private(set) var persistsIdentifiers: Bool = true

  private(set) var hasInitialIdentifier: Bool = false

  private(set) var authStartIdentifierWasPrefilled: Bool = false

  private(set) var authStartPhoneNumberWasPrefilled: Bool = false

  private(set) var hasInitialFirstName: Bool = false

  private(set) var hasInitialLastName: Bool = false

  private(set) var prefilledFieldsAreLocked = false

  private(set) var unsafeMetadata: JSON?

  private var environmentRefreshCheckpoint: Clerk.EnvironmentRefreshCheckpoint?

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

  func clearSensitiveFields() {
    signInPassword = ""
    signInNewPassword = ""
    signInConfirmNewPassword = ""
    signInBackupCode = ""
    signUpPassword = ""
  }

  func storeLastUsedIdentifierType(_ identifierType: LastUsedAuth) {
    guard persistsIdentifiers else { return }
    LastUsedAuth.storeIdentifierType(identifierType, userDefaults: userDefaults)
  }

  var signInPassword = ""
  var signInNewPassword = ""
  var signInConfirmNewPassword = ""
  var signInBackupCode = ""

  var signUpFirstName = ""
  var signUpLastName = ""
  var signUpPassword = ""
  var signUpUsername = ""
  var signUpEmailAddress = ""
  var signUpPhoneNumber = ""
  var signUpLegalAccepted = false
}

enum AuthStartField {
  case emailOrUsername
  case phoneNumber
}

extension AuthState {
  func environmentRefreshCheckpoint(for clerk: Clerk) -> Clerk.EnvironmentRefreshCheckpoint {
    if let environmentRefreshCheckpoint {
      return environmentRefreshCheckpoint
    }

    let checkpoint = clerk.environmentRefreshCheckpoint
    environmentRefreshCheckpoint = checkpoint
    return checkpoint
  }

  var authStartIdentifierIsLocked: Bool {
    prefilledFieldsAreLocked && authStartIdentifierWasPrefilled && !authStartIdentifier.isEmptyTrimmed
  }

  var authStartPhoneNumberIsLocked: Bool {
    prefilledFieldsAreLocked && authStartPhoneNumberWasPrefilled && !authStartPhoneNumber.isEmptyTrimmed
  }

  func authStartFieldIsLocked(_ field: AuthStartField?) -> Bool {
    switch field {
    case .emailOrUsername:
      authStartIdentifierIsLocked
    case .phoneNumber:
      authStartPhoneNumberIsLocked
    case nil:
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
