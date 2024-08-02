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
        public let captchaPublicKey: String?
        public let captchaWidgetType: CaptchaWidgetType?
        public let captchaPublicKeyInvisible: String?
        public let captchaProvider: CaptchaProvider?
        
        public enum PreferredSignInStrategy: String, Codable, CodingKeyRepresentable, Sendable {
            case password
            case otp
            case unknown
            
            public init(from decoder: Decoder) throws {
                self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
            }
        }
        
        public enum CaptchaWidgetType: String, Codable, CodingKeyRepresentable, Sendable {
            case invisible
            case smart
            case unknown
            
            public init(from decoder: Decoder) throws {
                self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
            }
        }
        
        public enum CaptchaProvider: String, Codable, CodingKeyRepresentable, Sendable {
            case turnstile
            case unknown
            
            public init(from decoder: Decoder) throws {
                self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
            }
        }
    }
    
}

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
            
            public var strategyEnum: Strategy? {
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
    
    public var socialProviders: [SocialProvider] {
        let authenticatableStrategies = social.values.filter({ $0.enabled }).map(\.strategy)
        
        return authenticatableStrategies.compactMap { strategy in
            SocialProvider(strategy: strategy)
        }
    }
        
    public var authenticatableSocialProviders: [SocialProvider] {
        let authenticatableStrategies = social.values.filter({ $0.enabled && $0.authenticatable }).map(\.strategy)
        
        return authenticatableStrategies.compactMap { strategy in
            SocialProvider(strategy: strategy)
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
    
}

extension Clerk.Environment.DisplayConfig {
    
    public var botProtectionIsEnabled: Bool {
        captchaWidgetType != nil
    }
    
}

extension Clerk.Environment {
    
    var nameIsEnabled: Bool {
        userSettings.config(for: "first_name")?.enabled == true ||
        userSettings.config(for: "last_name")?.enabled == true
    }
    
}
