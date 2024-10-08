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
        public let passkeySettings: PasskeySettings?
        
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
            public let name: String
            public let logoUrl: String?
        }
        
        public struct Actions: Codable, Equatable, Sendable {
            public var deleteSelf: Bool = false
            public var createOrganization: Bool = false
        }
        
        public struct PasskeySettings: Codable, Equatable, Sendable {
            public let allowAutofill: Bool
            public let showSignInButton: Bool
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
    
    var instanceIsPasswordBased: Bool {
        guard let passwordConfig = config(for: "password") else { return false }
        return passwordConfig.enabled && passwordConfig.required
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
    
    var preferredEmailVerificationStrategy: Strategy? {
        guard let emailAttribute = config(for: "email_address") else { return nil }
        let strategies = emailAttribute.verificationStrategies
        
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
