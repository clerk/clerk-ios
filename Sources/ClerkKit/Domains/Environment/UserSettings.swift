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

extension Clerk.Environment.UserSettings {

    package static var mock: Self {
        .init(
            attributes: [
                "email_address": .init(
                    enabled: true,
                    required: false,
                    usedForFirstFactor: true,
                    firstFactors: nil,
                    usedForSecondFactor: false,
                    secondFactors: nil,
                    verifications: nil,
                    verifyAtSignUp: true
                ),
                "phone_number": .init(
                    enabled: true,
                    required: false,
                    usedForFirstFactor: true,
                    firstFactors: nil,
                    usedForSecondFactor: true,
                    secondFactors: nil,
                    verifications: nil,
                    verifyAtSignUp: true
                ),
                "username": .init(
                    enabled: true,
                    required: false,
                    usedForFirstFactor: true,
                    firstFactors: nil,
                    usedForSecondFactor: false,
                    secondFactors: nil,
                    verifications: nil,
                    verifyAtSignUp: false
                ),
                "first_name": .init(
                    enabled: true,
                    required: false,
                    usedForFirstFactor: false,
                    firstFactors: nil,
                    usedForSecondFactor: false,
                    secondFactors: nil,
                    verifications: nil,
                    verifyAtSignUp: false
                ),
                "last_name": .init(
                    enabled: true,
                    required: false,
                    usedForFirstFactor: false,
                    firstFactors: nil,
                    usedForSecondFactor: false,
                    secondFactors: nil,
                    verifications: nil,
                    verifyAtSignUp: false
                ),
                "password": .init(
                    enabled: true,
                    required: false,
                    usedForFirstFactor: true,
                    firstFactors: nil,
                    usedForSecondFactor: false,
                    secondFactors: nil,
                    verifications: nil,
                    verifyAtSignUp: true
                ),
                "passkey": .init(
                    enabled: true,
                    required: false,
                    usedForFirstFactor: true,
                    firstFactors: nil,
                    usedForSecondFactor: false,
                    secondFactors: nil,
                    verifications: nil,
                    verifyAtSignUp: true
                ),
                "authenticator_app": .init(
                    enabled: true,
                    required: false,
                    usedForFirstFactor: false,
                    firstFactors: nil,
                    usedForSecondFactor: true,
                    secondFactors: nil,
                    verifications: nil,
                    verifyAtSignUp: true
                ),
                "backup_code": .init(
                    enabled: true,
                    required: false,
                    usedForFirstFactor: false,
                    firstFactors: nil,
                    usedForSecondFactor: true,
                    secondFactors: nil,
                    verifications: nil,
                    verifyAtSignUp: true
                )
            ],
            signUp: .init(
                customActionRequired: false,
                progressive: false,
                mode: "",
                legalConsentEnabled: true
            ),
            social: [
                "oauth_google": .init(
                    enabled: true,
                    required: false,
                    authenticatable: true,
                    strategy: "oauth_google",
                    notSelectable: false,
                    name: "Google",
                    logoUrl: ""
                ),
                "oauth_apple": .init(
                    enabled: true,
                    required: false,
                    authenticatable: true,
                    strategy: "oauth_apple",
                    notSelectable: false,
                    name: "Apple",
                    logoUrl: ""
                ),
                "oauth_slack": .init(
                    enabled: true,
                    required: false,
                    authenticatable: true,
                    strategy: "oauth_slack",
                    notSelectable: false,
                    name: "Slack",
                    logoUrl: ""
                )
            ],
            actions: .init(
                deleteSelf: true,
                createOrganization: true
            ),
            passkeySettings: .init(
                allowAutofill: true,
                showSignInButton: true
            )
        )
    }

}
