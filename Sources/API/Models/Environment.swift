//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import Foundation

extension Clerk {
        
    public struct Environment: Codable {
        public let authConfig: AuthConfig
        public let userSettings: UserSettings
        public let displayConfig: DisplayConfig
        
        init(
            authConfig: AuthConfig = .init(),
            userSettings: UserSettings = .init(),
            displayConfig: DisplayConfig = .init()
        ) {
            self.authConfig = authConfig
            self.userSettings = userSettings
            self.displayConfig = displayConfig
        }
    }
}

extension Clerk.Environment {
    
    public struct AuthConfig: Codable {
        public let singleSessionMode: Bool
        
        public init(singleSessionMode: Bool = true) {
            self.singleSessionMode = singleSessionMode
        }
    }
    
}

extension Clerk.Environment {
    
    public struct DisplayConfig: Codable {
        public let applicationName: String
        public let preferredSignInStrategy: PreferredSignInStrategy
        public let branded: Bool
        
        public enum PreferredSignInStrategy: String, Codable, CodingKeyRepresentable {
            case password, otp
        }
        
        public init(
            applicationName: String = "",
            preferredSignInStrategy: PreferredSignInStrategy = .password,
            branded: Bool = true
        ) {
            self.applicationName = applicationName
            self.preferredSignInStrategy = preferredSignInStrategy
            self.branded = branded
        }
    }
    
}

extension Clerk.Environment {
    
    public struct UserSettings: Codable, Equatable {
        
        let attributes: [Attribute: AttributesConfig]
        /// key is oauth social provider strategy (`oauth_google`, `oauth_github`, etc.)
        let social: [String: SocialConfig]
        
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
            
            var strategyEnum: Strategy? {
                Strategy(stringValue: strategy)
            }
        }
        
        public init(
            attributes: [Attribute : AttributesConfig] = [:],
            social: [String : SocialConfig] = [:]
        ) {
            self.attributes = attributes
            self.social = social
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
