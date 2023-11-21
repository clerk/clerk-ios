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
            sessions: [.mockSession1],
            lastActiveSessionId: "1"
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
            id: "1",
            emailAddress: "ClerkUser@clerk.dev",
            verification: .init(status: .verified)
        )
    }
    
    static var mock2: EmailAddress {
        .init(
            id: "2",
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
    
    static var mockGithub: ExternalAccount {
        let jsonData = """
        {
          "object": "external_account",
          "id": "1",
          "provider": "oauth_github",
          "identification_id": "1",
          "provider_user_id": "1",
          "approved_scopes": "read:user user:email",
          "email_address": "ClerkUser@clerk.dev",
          "first_name": "Clerk",
          "last_name": "User",
          "avatar_url": "https://avatars.com",
          "image_url": "https://img.clerk.com",
          "username": "clerkuser",
          "public_metadata": {},
          "label": null,
          "verification": {
            "status": "unverified",
            "strategy": "oauth_github",
            "attempts": null,
            "expire_at": 1699475468572
          }
        }
        """.data(using: .utf8)!

        let externalAccount = try! JSONDecoder.clerkDecoder.decode(ExternalAccount.self, from: jsonData)
        return externalAccount
    }
    
    static var mockGoogle: ExternalAccount {
        let jsonData = """
        {
          "object": "external_account",
          "id": "2",
          "provider": "oauth_google",
          "identification_id": "2",
          "provider_user_id": "1",
          "approved_scopes": "email https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile openid profile",
          "email_address": "ClerkUser@clerk.dev",
          "first_name": "Clerk",
          "last_name": "User",
          "avatar_url": "https://lh3.googleusercontent.com/a/1",
          "image_url": "https://img.clerk.com",
          "username": null,
          "public_metadata": {},
          "label": null,
          "verification": {
            "status": "verified",
            "strategy": "oauth_google",
            "attempts": null,
            "expire_at": 1699475321830
          }
        }
        """.data(using: .utf8)!

        let externalAccount = try! JSONDecoder.clerkDecoder.decode(ExternalAccount.self, from: jsonData)
        return externalAccount
    }
    
}

extension Factor {
    
    static var mock: Factor {
        .init(
            strategy: .emailCode,
            safeIdentifier: "ClerkUser@clerk.dev",
            emailAddressId: "1",
            phoneNumberId: "1",
            web3WalletId: nil,
            primary: true,
            default: nil
        )
    }
    
}

extension PhoneNumber {
    
    static var mock1: PhoneNumber {
        .init(
            id: "1",
            phoneNumber: "+12015550123",
            verification: .init(status: .verified)
        )
    }
    
    static var mock2: PhoneNumber {
        .init(
            id: "2",
            phoneNumber: "+12015550456",
            verification: .init(status: .unverified)
        )
    }
    
}

extension Session {
    
    public static let mockSession1 = Session(
        id: "1",
        status: .active,
        expireAt: Date().addingTimeInterval(3600), // expires in 1 hour
        abandonAt: .distantPast,
        lastActiveAt: Date().addingTimeInterval(-300), // last active 5 minutes ago
        latestActivity: SessionActivity(
            id: "1",
            browserName: "Safari",
            browserVersion: "15.0",
            deviceType: "Macintosh",
            ipAddress: "192.168.0.1",
            city: "New York",
            country: "USA",
            isMobile: false
        ),
        lastActiveOrganizationId: "1",
        actor: "1",
        user: .mock,
        publicUserData: ["name": "John Doe", "email": "john.doe@example.com"],
        createdAt: Date().addingTimeInterval(-3600), // created 1 hour ago
        updatedAt: Date().addingTimeInterval(-2400) // updated 40 minutes ago
    )

    public static let mockSession2 = Session(
        id: "2",
        status: .expired,
        expireAt: Date().addingTimeInterval(-3600), // expired 1 hour ago
        abandonAt: .distantPast,
        lastActiveAt: Date().addingTimeInterval(-7200), // last active 2 hours ago
        latestActivity: SessionActivity(
            id: "2",
            browserName: "Chrome",
            browserVersion: "94.0",
            deviceType: nil,
            ipAddress: "172.16.0.1",
            city: "San Francisco",
            country: "USA",
            isMobile: false
        ),
        lastActiveOrganizationId: nil,
        actor: "2",
        user: .mock,
        publicUserData: ["name": "Jane Smith", "email": "jane.smith@example.com"],
        createdAt: Date().addingTimeInterval(-10800), // created 3 hours ago
        updatedAt: Date().addingTimeInterval(-8100) // updated 2.25 hours ago
    )

    public static let mockSession3 = Session(
        id: "3",
        status: .revoked,
        expireAt: Date().addingTimeInterval(1800), // expires in 30 minutes
        abandonAt: .distantPast,
        lastActiveAt: Date().addingTimeInterval(-600), // last active 10 minutes ago
        latestActivity: SessionActivity(
            id: "activity2",
            browserName: "Chrome",
            browserVersion: "94.0",
            deviceType: "iPhone",
            ipAddress: "172.16.0.1",
            city: "San Francisco",
            country: "USA",
            isMobile: true
        ),
        lastActiveOrganizationId: "org456",
        actor: "3",
        user: .mock,
        publicUserData: nil,
        createdAt: Date().addingTimeInterval(-2700), // created 45 minutes ago
        updatedAt: Date().addingTimeInterval(-1200) // updated 20 minutes ago
    )
    
}

extension SignIn {
    
    static var mock: SignIn {
        .init(
            id: "1",
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
    
    static var mock: User {
        .init(
            firstName: "Clerk",
            lastName: "User",
            imageUrl: "image",
            primaryEmailAddressId: "1",
            primaryPhoneNumberId: "1",
            emailAddresses: [.mock1, .mock2],
            phoneNumbers: [.mock1, .mock2],
            externalAccounts: [.mockGoogle, .mockGithub]
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
