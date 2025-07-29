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

    var allSocialProviders: [OAuthProvider] {
        guard let social = userSettings?.social else {
            return []
        }

        let enabledProviders = social.filter(\.value.enabled)

        return enabledProviders.map({
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

    var mutliSessionModeIsEnabled: Bool {
        guard let authConfig else { return false }
        return authConfig.singleSessionMode == false
    }

    var billingIsEnabled: Bool {
        guard let commerceSettings else { return false }
        return commerceSettings.billing.enabled
    }

    var passwordIsEnabled: Bool {
        guard let userSettings else { return false }
        return userSettings.attributes.contains { key, value in
            key == "password" && value.enabled
        }
    }

    var passkeyIsEnabled: Bool {
        guard let userSettings else { return false }
        return userSettings.attributes.contains { key, value in
            key == "passkey" && value.enabled
        }
    }

    var mfaIsEnabled: Bool {
        guard let userSettings else { return false }
        return userSettings.attributes.contains { _, value in
            value.enabled && value.usedForSecondFactor
        }
    }

    var mfaAuthenticatorAppIsEnabled: Bool {
        guard let userSettings else { return false }
        return userSettings.attributes.contains { key, value in
            key == "authenticator_app" && value.enabled && value.usedForSecondFactor
        }
    }

    var mfaPhoneCodeIsEnabled: Bool {
        guard let userSettings else { return false }
        return userSettings.attributes.contains { key, value in
            key == "phone_number" && value.enabled && value.usedForSecondFactor
        }
    }

    var mfaBackupCodeIsEnabled: Bool {
        guard let userSettings else { return false }
        return userSettings.attributes.contains { key, value in
            key == "backup_code" && value.enabled && value.usedForSecondFactor
        }
    }

    var deleteSelfIsEnabled: Bool {
        guard let userSettings else { return false }
        return userSettings.actions.deleteSelf
    }

    var emailIsEnabled: Bool {
        guard let userSettings else { return false }
        return userSettings.attributes.contains { key, value in
            key == "email_address" && value.enabled
        }
    }

    var phoneNumberIsEnabled: Bool {
        guard let userSettings else { return false }
        return userSettings.attributes.contains { key, value in
            key == "phone_number" && value.enabled
        }
    }

    var usernameIsEnabled: Bool {
        guard let userSettings else { return false }
        return userSettings.attributes.contains { key, value in
            key == "username" && value.enabled
        }
    }

    var firstNameIsEnabled: Bool {
        guard let userSettings else { return false }
        return userSettings.attributes.contains { key, value in
            key == "first_name" && value.enabled
        }
    }

    var lastNameIsEnabled: Bool {
        guard let userSettings else { return false }
        return userSettings.attributes.contains { key, value in
            key == "last_name" && value.enabled
        }
    }

}

#endif
