//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import Foundation

extension Clerk {
        
    public struct Environment: Codable, Sendable {
        public let authConfig: AuthConfig
        public let userSettings: UserSettings
        public let displayConfig: DisplayConfig
    }
}

extension Clerk.Environment {
    
    @discardableResult @MainActor
    public static func get() async throws -> Clerk.Environment {
        let request = ClerkAPI.v1.environment.get
        let environment = try await Clerk.shared.apiClient.send(request).value
        Clerk.shared.environment = environment
        return environment
    }
    
}

extension Clerk.Environment {
    
    public struct AuthConfig: Codable, Sendable {
        public let singleSessionMode: Bool
    }
    
}

extension Clerk.Environment {
    
    public struct DisplayConfig: Codable, Sendable {
        public let applicationName: String
        public let preferredSignInStrategy: PreferredSignInStrategy
        public let branded: Bool
        public let logoImageUrl: String
        public let homeUrl: String
        
        public enum PreferredSignInStrategy: String, Codable, CodingKeyRepresentable, Sendable {
            case password, otp
        }
    }
    
}

extension Clerk.Environment {
    
    public struct UserSettings: Codable, Equatable, Sendable {
        
        let attributes: [Attribute: AttributesConfig]
        /// key is oauth social provider strategy (`oauth_google`, `oauth_github`, etc.)
        let social: [String: SocialConfig]
        let actions: Actions
        
        public enum Attribute: String, Codable, CodingKeyRepresentable, Equatable, Sendable {
            case emailAddress
            case phoneNumber
            case username
            case web3Wallet
            case firstName
            case lastName
            case password
            case authenticatorApp
            case ticket
            case backupCode
            case passkey
        }
        
        public struct AttributesConfig: Codable, Equatable, Sendable {
            public let enabled: Bool
            public let required: Bool
            public let usedForFirstFactor: Bool
            public let firstFactors: [String]?
            public let usedForSecondFactor: Bool
            public let secondFactors: [String]?
            public let verifications: [String]?
            public let verifyAtSignUp: Bool
            
            public var verificationStrategies: [Strategy] {
                verifications?.compactMap({ .init(stringValue: $0) }) ?? []
            }
        }
        
        public struct SocialConfig: Codable, Equatable, Sendable {
            public let enabled: Bool
            public let required: Bool
            public let authenticatable: Bool
            public let strategy: String
            public let notSelectable: Bool
            
            var strategyEnum: Strategy? {
                Strategy(stringValue: strategy)
            }
        }
        
        public struct Actions: Codable, Equatable, Sendable {
            public var deleteSelf: Bool = false
            public var createOrganization: Bool = false
        }
    }
}

extension Clerk.Environment.UserSettings {
    
    func config(for attribute: Attribute) -> AttributesConfig? {
        attributes[attribute]
    }
    
    var enabledAttributes: [Attribute: AttributesConfig] {
        attributes.filter({ $0.value.enabled })
    }
    
    var firstFactorAttributes: [Attribute: AttributesConfig] {
        enabledAttributes.filter(\.value.usedForFirstFactor)
    }
    
    var secondFactorAttributes: [Attribute: AttributesConfig] {
        enabledAttributes.filter(\.value.usedForSecondFactor)
    }
    
    func availableSecondFactors(user: User) -> [Attribute: AttributesConfig] {
        var secondFactors = secondFactorAttributes
        
        if user.totpEnabled {
            secondFactors.removeValue(forKey: .authenticatorApp)
        }
        
        
        if user.backupCodeEnabled || !user.twoFactorEnabled {
            secondFactors.removeValue(forKey: .backupCode)
        }
        
        return secondFactors
    }
    
    var requiredAttributes: [Attribute: AttributesConfig] {
        enabledAttributes.filter({ $0.value.required })
    }
    
    var instanceIsPasswordBased: Bool {
        guard let passwordConfig = config(for: .password) else { return false }
        return passwordConfig.enabled && passwordConfig.required
    }
    
    var hasValidAuthFactor: Bool {
        if enabledAttributes.contains(where: { $0.key == .emailAddress || $0.key == .phoneNumber }) {
            return true
        }
        
        if instanceIsPasswordBased { return true }
        
        return false
     }
        
    var enabledThirdPartyProviders: [ExternalProvider] {
        let authenticatableStrategies = social.values.filter({ $0.enabled && $0.authenticatable }).map(\.strategy)
        return authenticatableStrategies.compactMap { strategy in
            ExternalProvider(strategy: strategy)
        }
    }
    
    var attributesToVerifyAtSignUp: [Attribute: AttributesConfig] {
        enabledAttributes.filter({ $0.value.verifyAtSignUp })
    }
    
    private func userAttributeConfig(for key: Attribute) -> AttributesConfig? {
        return enabledAttributes.first(where: { $0.key == key && $0.value.enabled })?.value
    }
    
    var preferredEmailVerificationStrategy: Strategy? {
        let emailAttribute = userAttributeConfig(for: .emailAddress)
        let strategies = emailAttribute?.verificationStrategies ?? []
        
        if strategies.contains(where: { $0 == .emailCode }) {
            return .emailCode
        } 
//        else if strategies.contains(where: { $0 == .emailLink }) {
//            return .emailLink
//        }
        
        return nil
    }
    
}
