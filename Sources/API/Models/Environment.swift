//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import Foundation

extension Clerk {
        
    public struct Environment: Codable {
        
        public init(
            authConfig: AuthConfig = .init(),
            userSettings: UserSettings = .init(),
            displayConfig: DisplayConfig = .init()
        ) {
            self.authConfig = authConfig
            self.userSettings = userSettings
            self.displayConfig = displayConfig
        }
        
        public var authConfig: AuthConfig
        public var userSettings: UserSettings
        public var displayConfig: DisplayConfig
    }
}

extension Clerk.Environment {
    
    public struct AuthConfig: Codable {
        
        public init(
            singleSessionMode: Bool = true
        ) {
            self.singleSessionMode = singleSessionMode
        }
        
        public let singleSessionMode: Bool
    }
    
}

extension Clerk.Environment {
    
    public struct DisplayConfig: Codable {
        
        public init(
            applicationName: String = "",
            preferredSignInStrategy: PreferredSignInStrategy = .password,
            branded: Bool = true
        ) {
            self.applicationName = applicationName
            self.preferredSignInStrategy = preferredSignInStrategy
            self.branded = branded
        }
        
        public let applicationName: String
        public let preferredSignInStrategy: PreferredSignInStrategy
        public let branded: Bool
        
        public enum PreferredSignInStrategy: String, Codable, CodingKeyRepresentable {
            case password, otp
        }
    }
    
}

extension Clerk.Environment {
    
    public struct UserSettings: Codable, Equatable {
        
        public init(
            attributes: [Attribute : AttributesConfig] = [:],
            social: [String : SocialConfig] = [:]
        ) {
            self.attributes = attributes
            self.social = social
        }
        
        var attributes: [Attribute: AttributesConfig] = [:]
        /// key is oauth social provider strategy (`oauth_google`, `oauth_github`, etc.)
        var social: [String: SocialConfig] = [:]
        
        public enum Attribute: String, Codable, CodingKeyRepresentable, Equatable {
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
        }
        
        public struct AttributesConfig: Codable, Equatable {
            public let enabled: Bool
            public let required: Bool
            public let usedForFirstFactor: Bool
            public let firstFactors: [String]
            public let usedForSecondFactor: Bool
            public let secondFactors: [String]
            public let verifications: [String]
            public let verifyAtSignUp: Bool
            
            public var verificationStrategies: [Strategy] {
                verifications.compactMap({ .init(stringValue: $0) })
            }
        }
        
        public struct SocialConfig: Codable, Equatable {
            public let enabled: Bool
            public let required: Bool
            public let authenticatable: Bool
            public let strategy: String
            public let notSelectable: Bool
        }
    }
}

extension Clerk.Environment.UserSettings {
    
    public func config(for attribute: Attribute) -> AttributesConfig? {
        attributes[attribute]
    }
    
    public var enabledAttributes: [Attribute: AttributesConfig] {
        attributes.filter({ $0.value.enabled })
    }
    
    public var firstFactorAttributes: [Attribute: AttributesConfig] {
        enabledAttributes.filter(\.value.usedForFirstFactor)
    }
    
    public var secondFactorAttributes: [Attribute: AttributesConfig] {
        enabledAttributes.filter(\.value.usedForSecondFactor)
    }
    
    public func availableSecondFactors(user: User) -> [Attribute: AttributesConfig] {
        var secondFactors = secondFactorAttributes
        
        if user.totpEnabled {
            secondFactors.removeValue(forKey: .authenticatorApp)
        }
        
        
        if user.backupCodeEnabled || !user.twoFactorEnabled {
            secondFactors.removeValue(forKey: .backupCode)
        }
        
        return secondFactors
    }
    
    public var requiredAttributes: [Attribute: AttributesConfig] {
        enabledAttributes.filter({ $0.value.required })
    }
    
    public var instanceIsPasswordBased: Bool {
        guard let passwordConfig = config(for: .password) else { return false }
        return passwordConfig.enabled && passwordConfig.required
    }
    
    public var hasValidAuthFactor: Bool {
        if enabledAttributes.contains(where: { $0.key == .emailAddress || $0.key == .phoneNumber }) {
            return true
        }
        
        if instanceIsPasswordBased { return true }
        
        return false
     }
        
    public var enabledThirdPartyProviders: [ExternalProvider] {
        let authenticatableStrategies = social.values.filter({ $0.enabled && $0.authenticatable }).map(\.strategy)
        return authenticatableStrategies.compactMap { strategy in
            ExternalProvider(strategy: strategy)
        }
    }
    
    public var attributesToVerifyAtSignUp: [Attribute: AttributesConfig] {
        enabledAttributes.filter({ $0.value.verifyAtSignUp })
    }
    
    private func userAttributeConfig(for key: Attribute) -> AttributesConfig? {
        return enabledAttributes.first(where: { $0.key == key && $0.value.enabled })?.value
    }
    
    public var preferredEmailVerificationStrategy: Strategy? {
        let emailAttribute = userAttributeConfig(for: .emailAddress)
        let strategies = emailAttribute?.verificationStrategies ?? []
        
        if strategies.contains(where: { $0 == .emailCode }) {
            return .emailCode
        } else if strategies.contains(where: { $0 == .emailLink }) {
            return .emailLink
        }
        
        return nil
    }
    
}

extension Clerk.Environment {
    
    @MainActor
    public func get() async throws {
        let request = ClerkAPI.v1.environment.get
        Clerk.shared.environment = try await Clerk.apiClient.send(request).value
    }
    
}
