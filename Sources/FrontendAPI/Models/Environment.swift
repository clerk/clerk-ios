//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import Foundation

extension Clerk {
        
    public struct Environment: Decodable {
        
        public init(
            userSettings: UserSettings = .init(),
            displayConfig: DisplayConfig = .init()
        ) {
            self.userSettings = userSettings
            self.displayConfig = displayConfig
        }
        
        public var userSettings: UserSettings
        public var displayConfig: DisplayConfig
    }
}

extension Clerk.Environment {
    
    public struct DisplayConfig: Decodable {
        
        public init(
            applicationName: String = ""
        ) {
            self.applicationName = applicationName
        }
        
        public let applicationName: String
    }
    
}

extension Clerk.Environment {
    
    public struct UserSettings: Decodable {
        
        public init(
            attributes: [String : AttributesConfig] = [:],
            social: [String : SocialConfig] = [:]
        ) {
            self.attributes = attributes
            self.social = social
        }
        
        var attributes: [String: AttributesConfig] = [:]
        /// key is oauth social provider strategy (`oauth_google`, `oauth_github`, etc.)
        var social: [String: SocialConfig] = [:]
        
        public struct AttributesConfig: Decodable {
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
        
        public struct SocialConfig: Decodable {
            let enabled: Bool
            let required: Bool
            let authenticatable: Bool
            let strategy: String
            let notSelectable: Bool
        }
    }
}

extension Clerk.Environment.UserSettings {
    
    public var enabledAttributes: [AttributesConfig] {
        attributes.values.filter({ $0.enabled })
    }
    
    public var enabledThirdPartyProviders: [OAuthProvider] {
        let authenticatableStrategies = social.values.filter({ $0.enabled && $0.authenticatable }).map(\.strategy)
        return authenticatableStrategies.compactMap { strategy in
            OAuthProvider(strategy: strategy)
        }
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
