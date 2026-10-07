//
//  Environment+Ext.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation

extension Clerk.Environment {
  var authenticatableSocialProviders: [OAuthProvider] {
    let authenticatables = userSettings.social.filter { _, value in
      value.authenticatable && value.enabled
    }

    return authenticatables.map {
      OAuthProvider(strategy: $0.value.strategy)
    }.sorted()
  }

  var allSocialProviders: [OAuthProvider] {
    let enabledProviders = userSettings.social.filter { $0.value.enabled }

    return enabledProviders.map {
      OAuthProvider(strategy: $0.value.strategy)
    }.sorted()
  }

  /// The attributes the start screen offers for the given auth mode.
  ///
  /// `enabled` means an attribute can be used to sign up. Sign-in accepts any attribute used as a
  /// first factor, including one that is turned off for sign-up.
  func firstFactorAttributes(for mode: AuthView.Mode) -> [String] {
    userSettings.attributes
      .filter { _, value in
        switch mode {
        case .signIn, .signInOrUp:
          value.usedForFirstFactor
        case .signUp:
          value.enabled && value.usedForFirstFactor
        }
      }
      .map(\.key)
  }

  /// Total count of authentication methods available for signing in.
  ///
  /// This counts:
  /// - First factor identifiers (email, phone, username) used for sign-in
  /// - Authenticatable OAuth providers
  ///
  /// Used to determine whether to show authentication badges (only shown when > 1 method is available).
  var totalEnabledFirstFactorMethods: Int {
    let identifierKeys: Set = ["email_address", "phone_number", "username"]

    let firstFactorCount = userSettings.attributes
      .filter { key, value in
        identifierKeys.contains(key) && value.usedForFirstFactor
      }
      .count

    let oauthCount = authenticatableSocialProviders.count

    return firstFactorCount + oauthCount
  }

  var mutliSessionModeIsEnabled: Bool {
    authConfig.singleSessionMode == false
  }

  var passwordIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "password" && value.enabled
    }
  }

  /// Whether the instance lets users register and manage passkeys.
  var passkeyIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "passkey" && value.enabled
    }
  }

  /// Whether the instance accepts a passkey as a first factor when signing in.
  ///
  /// An instance can enable passkeys for registration and verification while leaving them
  /// out of the sign-in factors, so this is narrower than ``passkeyIsEnabled``.
  var passkeyFirstFactorIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "passkey" && value.enabled && value.usedForFirstFactor
    }
  }

  var mfaIsEnabled: Bool {
    userSettings.attributes.contains { _, value in
      value.usedForSecondFactor
    }
  }

  var mfaAuthenticatorAppIsEnabled: Bool {
    userSettings.attributes["authenticator_app"]?.usedForSecondFactor == true
  }

  var mfaPhoneCodeIsEnabled: Bool {
    userSettings.attributes["phone_number"]?.usedForSecondFactor == true
  }

  var mfaBackupCodeIsEnabled: Bool {
    userSettings.attributes["backup_code"]?.usedForSecondFactor == true
  }

  var emailIsAvailable: Bool {
    attributeIsAvailable("email_address")
  }

  var phoneNumberIsAvailable: Bool {
    attributeIsAvailable("phone_number")
  }

  var usernameIsAvailable: Bool {
    attributeIsAvailable("username")
  }

  private func attributeIsAvailable(_ key: String) -> Bool {
    guard let attribute = userSettings.attributes[key] else { return false }
    return attribute.enabled || attribute.usedForFirstFactor || attribute.usedForSecondFactor
  }

  var firstNameIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "first_name" && value.enabled
    }
  }

  var lastNameIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "last_name" && value.enabled
    }
  }

  var emailIsImmutable: Bool {
    userSettings.attributes["email_address"]?.immutable == true
  }

  var phoneNumberIsImmutable: Bool {
    userSettings.attributes["phone_number"]?.immutable == true
  }

  var usernameIsImmutable: Bool {
    userSettings.attributes["username"]?.immutable == true
  }
}

#endif
