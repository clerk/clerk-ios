//
//  Environment+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 4/14/25.
//

#if os(iOS)

import ClerkKit
import Foundation

public extension Clerk.Environment {
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

  var enabledFirstFactorAttributes: [String] {
    userSettings.attributes
      .filter { _, value in
        value.enabled && value.usedForFirstFactor
      }
      .map(\.key)
  }

  var mutliSessionModeIsEnabled: Bool {
    authConfig.singleSessionMode == false
  }

  var passwordIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "password" && value.enabled
    }
  }

  var passkeyIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "passkey" && value.enabled
    }
  }

  var mfaIsEnabled: Bool {
    userSettings.attributes.contains { _, value in
      value.enabled && value.usedForSecondFactor
    }
  }

  var mfaAuthenticatorAppIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "authenticator_app" && value.enabled && value.usedForSecondFactor
    }
  }

  var mfaPhoneCodeIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "phone_number" && value.enabled && value.usedForSecondFactor
    }
  }

  var mfaBackupCodeIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "backup_code" && value.enabled && value.usedForSecondFactor
    }
  }

  var deleteSelfIsEnabled: Bool {
    userSettings.actions.deleteSelf
  }

  var emailIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "email_address" && value.enabled
    }
  }

  var phoneNumberIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "phone_number" && value.enabled
    }
  }

  var usernameIsEnabled: Bool {
    userSettings.attributes.contains { key, value in
      key == "username" && value.enabled
    }
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

  internal var signUpIsPublic: Bool {
    userSettings.signUp.mode == "public"
  }

  /// Total count of enabled authentication methods.
  ///
  /// This counts:
  /// - First factor identifiers (email, phone, username) that are enabled
  /// - Authenticatable OAuth providers
  ///
  /// Used to determine whether to show authentication badges (only shown when > 1 method is available).
  var totalEnabledAuthMethods: Int {
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

  /// Whether the last used authentication badge can be shown based on identifier combinations.
  ///
  /// Badge can be shown when:
  /// - Email and/or username are enabled (without phone)
  /// - Only phone is enabled
  ///
  /// Badge should not be shown when phone is combined with email or username.
  var canShowLastUsedBadge: Bool {
    let hasEmail = userSettings.attributes.contains { key, value in
      key == "email_address" && value.enabled && value.usedForFirstFactor
    }
    let hasPhone = userSettings.attributes.contains { key, value in
      key == "phone_number" && value.enabled && value.usedForFirstFactor
    }
    let hasUsername = userSettings.attributes.contains { key, value in
      key == "username" && value.enabled && value.usedForFirstFactor
    }

    if hasPhone, hasEmail || hasUsername {
      return false
    }

    return true
  }
}

#endif
