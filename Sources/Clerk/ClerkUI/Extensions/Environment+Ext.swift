//
//  Environment+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 4/14/25.
//

#if os(iOS)

  import Foundation

  extension Clerk.Environment {

    var authenticatableSocialProviders: [OAuthProvider] {
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

    var enabledFirstFactorAttributes: [String] {
      guard let userSettings else { return [] }

      return userSettings.attributes
        .filter { _, value in
          value.enabled && value.usedForFirstFactor
        }
        .map(\.key)
    }

    var isMutliSessionModeEnabled: Bool {
      guard let authConfig else { return false }
      return authConfig.singleSessionMode == false
    }

    var isBillingEnabled: Bool {
      guard let commerceSettings else { return false }
      return commerceSettings.billing.enabled
    }

    var isPasswordEnabled: Bool {
      guard let userSettings else { return false }
      return userSettings.attributes.contains { key, value in
        key == "password" && value.enabled
      }
    }
    
    var isMfaEnabled: Bool {
      guard let userSettings else { return false }
      return userSettings.attributes.contains { _, value in
        value.enabled && value.usedForSecondFactor
      }
    }
    
    var isMfaAuthenticatorAppEnabled: Bool {
      guard let userSettings else { return false }
      return userSettings.attributes.contains { key, value in
        key == "authenticator_app" && value.enabled && value.usedForSecondFactor
      }
    }
    
    var isMfaPhoneCodeEnabled: Bool {
      guard let userSettings else { return false }
      return userSettings.attributes.contains { key, value in
        key == "phone_number" && value.enabled && value.usedForSecondFactor
      }
    }
    
    var isMfaBackupCodeEnabled: Bool {
      guard let userSettings else { return false }
      return userSettings.attributes.contains { key, value in
        key == "backup_code" && value.enabled && value.usedForSecondFactor
      }
    }
    
    var isDeleteSelfEnabled: Bool {
      guard let userSettings else { return false }
      return userSettings.actions.deleteSelf
    }

  }

#endif
