//
//  Environment+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 4/14/25.
//

#if os(iOS)

import ClerkKit
import Foundation

extension Clerk.Environment {
  public var authenticatableSocialProviders: [OAuthProvider] {
    let authenticatables = userSettings.social.filter { _, value in
      value.authenticatable && value.enabled
    }

    return authenticatables.map {
      OAuthProvider(strategy: $0.value.strategy)
    }.sorted()
  }

  public var allSocialProviders: [OAuthProvider] {
    let enabledProviders = userSettings.social.filter { $0.value.enabled }

    return enabledProviders.map {
      OAuthProvider(strategy: $0.value.strategy)
    }.sorted()
  }

  public var enabledFirstFactorAttributes: [String] {
    userSettings.attributes
      .filter { _, value in
        value.enabled && value.usedForFirstFactor
      }
      .map(\.key)
  }

  /// Total count of enabled authentication methods.
  ///
  /// This counts:
  /// - First factor identifiers (email, phone, username) that are enabled
  /// - Authenticatable OAuth providers
  ///
  /// Used to determine whether to show authentication badges (only shown when > 1 method is available).
  var totalEnabledFirstFactorMethods: Int {
    let identifierKeys: Set<String> = ["email_address", "phone_number", "username"]

    let firstFactorCount = userSettings.attributes
      .filter { key, value in
        identifierKeys.contains(key) &&
          value.enabled &&
          value.usedForFirstFactor
      }
      .count

    let oauthCount = authenticatableSocialProviders.count

    return firstFactorCount + oauthCount
  }

  public var mutliSessionModeIsEnabled: Bool {
    authConfig.singleSessionMode == false
  }

  public var passwordIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "password" && value.enabled
    }
  }

  public var passkeyIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "passkey" && value.enabled
    }
  }

  public var mfaIsEnabled: Bool {
    userSettings.attributes.contains { _, value in
      value.enabled && value.usedForSecondFactor
    }
  }

  public var mfaAuthenticatorAppIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "authenticator_app" && value.enabled && value.usedForSecondFactor
    }
  }

  public var mfaPhoneCodeIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "phone_number" && value.enabled && value.usedForSecondFactor
    }
  }

  public var mfaBackupCodeIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "backup_code" && value.enabled && value.usedForSecondFactor
    }
  }

  public var deleteSelfIsEnabled: Bool {
    userSettings.actions.deleteSelf
  }

  public var emailIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "email_address" && value.enabled
    }
  }

  public var phoneNumberIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "phone_number" && value.enabled
    }
  }

  public var usernameIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "username" && value.enabled
    }
  }

  public var firstNameIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "first_name" && value.enabled
    }
  }

  public var lastNameIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "last_name" && value.enabled
    }
  }

  var signUpIsPublic: Bool {
    userSettings.signUp.mode == "public"
  }
}

#endif
