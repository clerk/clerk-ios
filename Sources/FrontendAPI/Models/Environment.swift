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
            applicationName: String = ""
        ) {
            self.applicationName = applicationName
        }
        
        public let applicationName: String
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
            let enabled: Bool
            let required: Bool
            let usedForFirstFactor: Bool
            let firstFactors: [String]
            let usedForSecondFactor: Bool
            let secondFactors: [String]
            let verifications: [String]
            let verifyAtSignUp: Bool
            
            public var verificationStrategies: [Strategy] {
                verifications.compactMap({ .init(stringValue: $0) })
            }
        }
        
        public struct SocialConfig: Codable, Equatable {
            let enabled: Bool
            let required: Bool
            let authenticatable: Bool
            let strategy: String
            let notSelectable: Bool
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
        enabledAttributes.filter({ $0.value.usedForFirstFactor })
    }
    
    public var requiredAttributes: [Attribute: AttributesConfig] {
        enabledAttributes.filter({ $0.value.required })
    }
        
    public var enabledThirdPartyProviders: [OAuthProvider] {
        let authenticatableStrategies = social.values.filter({ $0.enabled && $0.authenticatable }).map(\.strategy)
        return authenticatableStrategies.compactMap { strategy in
            OAuthProvider(strategy: strategy)
        }
    }
    
    public var attributesToVerifyAtSignUp: [Attribute: AttributesConfig] {
        attributes.filter({ $0.value.verifyAtSignUp })
    }
    
    private func userAttributeConfig(for key: Attribute) -> AttributesConfig? {
        return attributes.first(where: { $0.key == key && $0.value.enabled })?.value
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
        let request = APIEndpoint
            .v1
            .environment
            .get
        
        Clerk.shared.environment = try await Clerk.apiClient.send(request).value
    }
    
}
