//
//  Mocks.swift
//
//
//  Created by Mike Pitre on 11/8/23.
//

#if DEBUG

import Foundation

extension Clerk {
    
    public static var mock: Clerk {
        let clerk = Clerk()
        clerk.client = .mock
        clerk.environment = .mock
        return clerk
    }
}

extension Client {
    
    static var mock: Client {
        return Client(
            signIn: .mock,
            signUp: .mock,
            sessions: [.mock],
            lastActiveSessionId: "123"
        )
    }
    
}

extension ClerkAPIError {
    
    static var mock: ClerkAPIError {
        return ClerkAPIError(
            code: "mock_code",
            message: "Mock error message",
            longMessage: "This is a longer mock error message."
        )
    }
    
}

extension EmailAddress {
    
    static var mock1: EmailAddress {
        .init(
            id: "123",
            emailAddress: "ClerkUser@clerk.dev",
            verification: .init(status: .verified)
        )
    }
    
    static var mock2: EmailAddress {
        .init(
            id: "456",
            emailAddress: "ClerkUser2@clerk.dev",
            verification: .init(status: .unverified)
        )
    }
    
}

extension Clerk.Environment {
    
    static var mock: Clerk.Environment {
        return Clerk.Environment(
            userSettings: .mock,
            displayConfig: .mock
        )
    }
    
}

extension Clerk.Environment.DisplayConfig {
    
    static var mock: Clerk.Environment.DisplayConfig {
        return Clerk.Environment.DisplayConfig(
            applicationName: "MockApp"
        )
    }
    
}

extension Clerk.Environment.UserSettings {
    
    static var mock: Self {
        .init(
            attributes: [
                "phone_number": .mockPhoneNumber,
                "email_address": .mockEmail
            ],
            social: [
                "oauth_apple": .mockApple,
                "oauth_google": .mockGoogle
            ]
        )
    }
    
}

extension Clerk.Environment.UserSettings.AttributesConfig {
    
    static var mockPhoneNumber: Self {
        .init(
            enabled: true,
            required: false,
            usedForFirstFactor: true,
            firstFactors: [],
            usedForSecondFactor: false,
            secondFactors: [],
            verifications: ["phone_code"],
            verifyAtSignUp: true
        )
    }
    
    static var mockEmail: Self {
        .init(
            enabled: true,
            required: false,
            usedForFirstFactor: true,
            firstFactors: [],
            usedForSecondFactor: false,
            secondFactors: [],
            verifications: ["email_code"],
            verifyAtSignUp: true
        )
    }
    
}

extension Clerk.Environment.UserSettings.SocialConfig {
    
    static var mockApple: Self {
        .init(
            enabled: true,
            required: false,
            authenticatable: true,
            strategy: "oauth_apple",
            notSelectable: false
        )
    }
    
    static var mockGoogle: Self {
        .init(
            enabled: true,
            required: false,
            authenticatable: true,
            strategy: "oauth_google",
            notSelectable: false
        )
    }
    
}

extension ExternalAccount {
    
    static var mock: ExternalAccount {
        return ExternalAccount(
            id: "mock_id",
            provider: "mock_provider",
            identificationId: "mock_identification_id",
            providerUserId: "mock_provider_user_id",
            approvedScopes: "mock_approved_scopes",
            emailAddress: "mock_email@example.com",
            firstName: "Mock",
            lastName: "User",
            avatarUrl: "https://example.com/avatar.png",
            imageUrl: "https://example.com/image.png",
            username: "mock_username",
            publicMetadata: [:],
            label: "mock_label",
            verification: .mock
        )
    }
    
}

extension Factor {
    
    static var mock: Factor {
        .init(
            strategy: .emailCode,
            safeIdentifier: "ClerkUser@clerk.dev",
            emailAddressId: "123",
            phoneNumberId: "123",
            web3WalletId: nil,
            primary: true,
            default: nil
        )
    }
    
}

extension PhoneNumber {
    
    static var mock1: PhoneNumber {
        .init(
            id: "123",
            phoneNumber: "+12015550123",
            verification: .init(status: .verified)
        )
    }
    
    static var mock2: PhoneNumber {
        .init(
            id: "456",
            phoneNumber: "+12015550456",
            verification: .init(status: .unverified)
        )
    }
    
}

extension Session {
    
    static var mock: Self {
        .init(
            id: "123",
            user: .mock,
            status: "active"
        )
    }
    
}

extension SignIn {
    
    static var mock: SignIn {
        .init(
            id: "123",
            status: .needsFirstFactor,
            supportedFirstFactors: [.mock],
            firstFactorVerification: .mock,
            identifier: "ClerkUser@clerk.dev",
            userData: .mock
        )
    }
    
}

extension SignUp {
    
    static var mock: SignUp {
        .init(
            unverifiedFields: [
                "email_address",
                "phone_number"
            ],
            emailAddress: "ClerkUser@clerk.dev",
            phoneNumber: "+12015550123"
        )
    }
    
}

extension SignUpVerification {
    
    static var signUpVerificationMock: SignUpVerification {
        return SignUpVerification(
            status: .verified,
            strategy: .emailCode,
            attempts: 1,
            expireAt: Date(),
            error: nil,
            externalVerificationRedirectUrl: "https://example.com",
            nextAction: "mock_next_action",
            supportedStrategies: ["strategy1", "strategy2"]
        )
    }
    
}

extension User {
    
    static var mock: Self {
        .init(
            firstName: "Clerk",
            lastName: "User",
            imageUrl: "image",
            primaryEmailAddressId: "123",
            primaryPhoneNumberId: "123",
            emailAddresses: [.mock1, .mock2],
            phoneNumbers: [.mock1, .mock2]
        )
    }
    
}

extension UserData {
    
    static var mock: Self {
        .init(
            firstName: "First",
            lastName: "Last",
            imageUrl: "",
            hasImage: true
        )
    }
    
}

extension Verification {
    
    static var mock: Verification {
        .init(
            status: .unverified,
            strategy: .emailCode,
            attempts: 0,
            expireAt: .distantFuture,
            error: nil
        )
    }
    
}

#endif
