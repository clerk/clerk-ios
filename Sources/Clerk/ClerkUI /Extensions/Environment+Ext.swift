//
//  Environment+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/19/25.
//

import Foundation

extension Clerk.Environment.UserSettings {
    
    func config(for attribute: String) -> AttributesConfig? {
        attributes[attribute]
    }
    
    var enabledAttributes: [String: AttributesConfig] {
        attributes.filter({ $0.value.enabled })
    }
    
    var firstFactorAttributes: [String: AttributesConfig] {
        enabledAttributes.filter(\.value.usedForFirstFactor)
    }
    
    var secondFactorAttributes: [String: AttributesConfig] {
        enabledAttributes.filter(\.value.usedForSecondFactor)
    }
    
    func availableSecondFactors(user: User) -> [String: AttributesConfig] {
        var secondFactors = secondFactorAttributes
        
        if user.totpEnabled {
            secondFactors.removeValue(forKey: "authenticator_app")
        }
        
        
        if user.backupCodeEnabled || !user.twoFactorEnabled {
            secondFactors.removeValue(forKey: "backup_code")
        }
        
        return secondFactors
    }
    
    var instanceIsPasswordBased: Bool {
        guard let passwordConfig = config(for: "password") else { return false }
        return passwordConfig.enabled && passwordConfig.required
    }
    
    var socialProviders: [OAuthProvider] {
        let authenticatableStrategies = social.values.filter({ $0.enabled }).map(\.strategy)
        
        return authenticatableStrategies.compactMap { strategy in
            OAuthProvider(strategy: strategy)
        }
    }
        
    var authenticatableSocialProviders: [OAuthProvider] {
        let authenticatableStrategies = social.values.filter({ $0.enabled && $0.authenticatable }).map(\.strategy)
        
        return authenticatableStrategies.compactMap { strategy in
            OAuthProvider(strategy: strategy)
        }
    }
    
    var attributesToVerifyAtSignUp: [String: AttributesConfig] {
        enabledAttributes.filter({ $0.value.verifyAtSignUp })
    }
    
    var preferredEmailVerificationStrategy: String? {
        if let emailAttribute = config(for: "email_address"),
           let strategies = emailAttribute.verifications,
           strategies.contains(where: { $0 == "email_code" }) {
            return "email_code"
        }
        
        return nil
    }
    
}
