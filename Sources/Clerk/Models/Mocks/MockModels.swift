//
//  ModelMocks.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

import Foundation

extension SignIn {
    
    public static var mock: SignIn {
        SignIn(
            id: "1",
            status: .needsIdentifier,
            supportedIdentifiers: [.emailAddress, .phoneNumber],
            identifier: User.mock.emailAddresses.first?.emailAddress,
            supportedFirstFactors: [.mock],
            supportedSecondFactors: nil,
            firstFactorVerification: .mockEmailCodeVerification,
            secondFactorVerification: nil,
            userData: nil,
            createdSessionId: nil
        )
    }
    
}

extension SignInFactor {
    
    public static var mock: SignInFactor {
        
        SignInFactor(
            strategy: "email_code",
            emailAddressId: "1",
            phoneNumberId: "1",
            safeIdentifier: User.mock.emailAddresses.first?.emailAddress,
            primary: true,
            default: true
        )
        
    }
    
}

extension SignUp {
    
    public static var mock: SignUp {
        SignUp(
            id: "1",
            status: .missingRequirements,
            requiredFields: [],
            optionalFields: [],
            missingFields: [],
            unverifiedFields: [],
            verifications: ["email_address": .mockEmailCodeVerification],
            username: User.mock.username,
            emailAddress: User.mock.emailAddresses.first?.emailAddress,
            phoneNumber: User.mock.phoneNumbers.first?.phoneNumber,
            web3Wallet: nil,
            hasPassword: User.mock.passwordEnabled,
            firstName: User.mock.firstName,
            lastName: User.mock.lastName,
            unsafeMetadata: nil,
            createdSessionId: nil,
            createdUserId: nil,
            abandonAt: .distantFuture
        )
    }
    
}

extension Verification {
    
    public static var mockEmailCodeVerification: Verification {
        Verification(
            status: .unverified,
            strategy: "email_code",
            attempts: nil,
            expireAt: .distantFuture,
            error: nil,
            nonce: nil
        )
    }
    
    public static var mockPhoneCodeVerification: Verification {
        Verification(
            status: .unverified,
            strategy: "phone_code",
            attempts: 0,
            expireAt: .distantFuture,
            error: nil,
            nonce: nil
        )
    }
    
    public static var mockPasskeyVerification: Verification {
        Verification(
            status: .unverified,
            strategy: "passkey",
            attempts: 0,
            expireAt: .distantFuture,
            error: nil,
            nonce: UUID().uuidString
        )
    }
    
}

extension User {
    
    public static var mock: User {
        User(
            id: "1",
            firstName: "First",
            lastName: "Last",
            username: "username",
            imageUrl: "",
            hasImage: false,
            primaryEmailAddressId: "1",
            emailAddresses: [.mock],
            primaryPhoneNumberId: "1",
            phoneNumbers: [.mock],
            passkeys: [.mock],
            passwordEnabled: true,
            twoFactorEnabled: true,
            totpEnabled: true,
            backupCodeEnabled: true,
            deleteSelfEnabled: true,
            externalAccounts: [],
            enterpriseAccounts: nil,
            publicMetadata: nil,
            unsafeMetadata: nil,
            lastSignInAt: .now,
            createdAt: .distantPast,
            updatedAt: .now,
            createOrganizationEnabled: true,
            legalAcceptedAt: .now
        )
    }
    
}

extension Passkey {
    
    public static var mock: Passkey {
        Passkey(
            id: UUID().uuidString,
            name: "iCloud Keychain",
            lastUsedAt: .now,
            createdAt: .distantPast,
            updatedAt: .now,
            verification: .mockPasskeyVerification
        )
    }
    
}

extension EmailAddress {
    
    public static var mock: EmailAddress {
        EmailAddress(
            id: "1",
            emailAddress: "user@email.com",
            reserved: false,
            verification: .mockEmailCodeVerification,
            linkedTo: nil
        )
    }
    
}

extension PhoneNumber {
    
    public static var mock: PhoneNumber {
        PhoneNumber(
            id: "1",
            phoneNumber: "15551234567",
            reservedForSecondFactor: false,
            defaultSecondFactor: false,
            verification: .mockPhoneCodeVerification,
            linkedTo: nil,
            backupCodes: nil
        )
    }
    
}
