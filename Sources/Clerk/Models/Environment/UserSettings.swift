//
//  UserSettings.swift
//  Clerk
//
//  Created by Mike Pitre on 8/2/24.
//

import Foundation

extension Clerk.Environment {
    
    struct UserSettings: Codable, Equatable, Sendable {
        
        let attributes: [String: AttributesConfig]
        let signUp: SignUp
        let social: [String: SocialConfig]
        let actions: Actions
        let passkeySettings: PasskeySettings?
        
        struct AttributesConfig: Codable, Equatable, Sendable {
            let enabled: Bool
            let required: Bool
            let usedForFirstFactor: Bool
            let firstFactors: [String]?
            let usedForSecondFactor: Bool
            let secondFactors: [String]?
            let verifications: [String]?
            let verifyAtSignUp: Bool
        }
        
        struct SignUp: Codable, Equatable, Sendable {
            let customActionRequired: Bool
            let progressive: Bool
            let mode: String
            let legalConsentEnabled: Bool
        }
        
        struct SocialConfig: Codable, Equatable, Sendable {
            let enabled: Bool
            let required: Bool
            let authenticatable: Bool
            let strategy: String
            let notSelectable: Bool
            let name: String
            let logoUrl: String?
        }
        
        struct Actions: Codable, Equatable, Sendable {
            var deleteSelf: Bool = false
            var createOrganization: Bool = false
        }
        
        struct PasskeySettings: Codable, Equatable, Sendable {
            let allowAutofill: Bool
            let showSignInButton: Bool
        }
    }
    
}
