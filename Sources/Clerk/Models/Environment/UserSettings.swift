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
        public let signUp: SignUp
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
        
        public struct SignUp: Codable, Equatable {
            public let captchaEnabled: Bool
            public let captchaWidgetType: String
            public let customActionRequired: Bool
            public let progressive: Bool
            public let mode: String
            public let legalConsentEnabled: Bool
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
