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
    guard let social = userSettings?.social else {
      return []
    }

    let authenticatables = social.filter { key, value in
      value.authenticatable && value.enabled
    }

    return authenticatables.map({
      OAuthProvider(strategy: $0.value.strategy)
    }).sorted()
  }

  public var allSocialProviders: [OAuthProvider] {
    guard let social = userSettings?.social else {
      return []
    }

    let enabledProviders = social.filter(\.value.enabled)

    return enabledProviders.map({
      OAuthProvider(strategy: $0.value.strategy)
    }).sorted()
  }

  public var enabledFirstFactorAttributes: [String] {
    guard let userSettings else { return [] }

    return userSettings.attributes
      .filter { _, value in
        value.enabled && value.usedForFirstFactor
      }
      .map(\.key)
  }

  public var mutliSessionModeIsEnabled: Bool {
    guard let authConfig else { return false }
    return authConfig.singleSessionMode == false
  }

  public var billingIsEnabled: Bool {
    guard let commerceSettings else { return false }
    return commerceSettings.billing.enabled
  }

  public var passwordIsEnabled: Bool {
    guard let userSettings else { return false }
    return userSettings.attributes.contains { key, value in
      key == "password" && value.enabled
    }
  }

  public var passkeyIsEnabled: Bool {
    guard let userSettings else { return false }
    return userSettings.attributes.contains { key, value in
      key == "passkey" && value.enabled
    }
  }

  public var mfaIsEnabled: Bool {
    guard let userSettings else { return false }
    return userSettings.attributes.contains { _, value in
      value.enabled && value.usedForSecondFactor
    }
  }

  public var mfaAuthenticatorAppIsEnabled: Bool {
    guard let userSettings else { return false }
    return userSettings.attributes.contains { key, value in
      key == "authenticator_app" && value.enabled && value.usedForSecondFactor
    }
  }

  public var mfaPhoneCodeIsEnabled: Bool {
    guard let userSettings else { return false }
    return userSettings.attributes.contains { key, value in
      key == "phone_number" && value.enabled && value.usedForSecondFactor
    }
  }

  public var mfaBackupCodeIsEnabled: Bool {
    guard let userSettings else { return false }
    return userSettings.attributes.contains { key, value in
      key == "backup_code" && value.enabled && value.usedForSecondFactor
    }
  }

  public var deleteSelfIsEnabled: Bool {
    guard let userSettings else { return false }
    return userSettings.actions.deleteSelf
  }

  public var emailIsEnabled: Bool {
    guard let userSettings else { return false }
    return userSettings.attributes.contains { key, value in
      key == "email_address" && value.enabled
    }
  }

  public var phoneNumberIsEnabled: Bool {
    guard let userSettings else { return false }
    return userSettings.attributes.contains { key, value in
      key == "phone_number" && value.enabled
    }
  }

  public var usernameIsEnabled: Bool {
    guard let userSettings else { return false }
    return userSettings.attributes.contains { key, value in
      key == "username" && value.enabled
    }
  }

  public var firstNameIsEnabled: Bool {
    guard let userSettings else { return false }
    return userSettings.attributes.contains { key, value in
      key == "first_name" && value.enabled
    }
  }

  public var lastNameIsEnabled: Bool {
    guard let userSettings else { return false }
    return userSettings.attributes.contains { key, value in
      key == "last_name" && value.enabled
    }
  }

}

#endif
