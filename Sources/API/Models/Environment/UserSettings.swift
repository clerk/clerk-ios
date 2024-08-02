//
//  UserSettings.swift
//  Clerk
//
//  Created by Mike Pitre on 8/2/24.
//

import Foundation

extension Clerk.Environment {
    
    public struct UserSettings: Codable, Equatable, Sendable {
        
        public let attributes: [String: AttributesConfig]
        public let social: [String: SocialConfig]
        public let actions: Actions
        
        public struct AttributesConfig: Codable, Equatable, Sendable {
            public let enabled: Bool
            public let required: Bool
            public let usedForFirstFactor: Bool
            public let firstFactors: [String]?
            public let usedForSecondFactor: Bool
            public let secondFactors: [String]?
            public let verifications: [String]?
            public let verifyAtSignUp: Bool
        }
        
        public struct SocialConfig: Codable, Equatable, Sendable {
            public let enabled: Bool
            public let required: Bool
            public let authenticatable: Bool
            public let strategy: String
            public let notSelectable: Bool
        }
        
        public struct Actions: Codable, Equatable, Sendable {
            public var deleteSelf: Bool = false
            public var createOrganization: Bool = false
        }
    }
    
}

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
    
    var requiredAttributes: [String: AttributesConfig] {
        enabledAttributes.filter({ $0.value.required })
    }
    
    var instanceIsPasswordBased: Bool {
        guard let passwordConfig = config(for: "password") else { return false }
        return passwordConfig.enabled && passwordConfig.required
    }
    
    var hasValidAuthFactor: Bool {
        if enabledAttributes.contains(where: { $0.key == "email_address" || $0.key == "phone_number" }) {
            return true
        }
        
        if instanceIsPasswordBased { return true }
        
        return false
     }
    
    public var socialProviders: [OAuthProvider] {
        let authenticatableStrategies = social.values.filter({ $0.enabled }).map(\.strategy)
        
        return authenticatableStrategies.compactMap { strategy in
            OAuthProvider(strategy: strategy)
        }
    }
        
    public var authenticatableSocialProviders: [OAuthProvider] {
        let authenticatableStrategies = social.values.filter({ $0.enabled && $0.authenticatable }).map(\.strategy)
        
        return authenticatableStrategies.compactMap { strategy in
            OAuthProvider(strategy: strategy)
        }
    }
    
    var attributesToVerifyAtSignUp: [String: AttributesConfig] {
        enabledAttributes.filter({ $0.value.verifyAtSignUp })
    }
    
    private func userAttributeConfig(for key: String) -> AttributesConfig? {
        return enabledAttributes.first(where: { $0.key == key && $0.value.enabled })?.value
    }
    
    var preferredEmailVerificationStrategy: Strategy? {
        let emailAttribute = userAttributeConfig(for: "email_address")
        let strategies = emailAttribute?.verificationStrategies ?? []
        
        if strategies.contains(where: { $0 == .emailCode }) {
            return .emailCode
        }
        
        return nil
    }
    
    var nameIsEnabled: Bool {
        config(for: "first_name")?.enabled == true ||
        config(for: "last_name")?.enabled == true
    }
    
}

extension Clerk.Environment.UserSettings.AttributesConfig {
    
    var verificationStrategies: [Strategy] {
        verifications?.compactMap({ .init(stringValue: $0) }) ?? []
    }
    
}

extension Clerk.Environment.UserSettings.SocialConfig {
    
    var strategyEnum: Strategy? {
        Strategy(stringValue: strategy)
    }
    
}
