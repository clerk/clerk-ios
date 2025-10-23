//
//  Verification.swift
//
//
//  Created by Mike Pitre on 10/26/23.
//

import Foundation

/// The state of the verification process of a sign-in or sign-up attempt.
public struct Verification: Codable, Equatable, Hashable, Sendable {

    /// The state of the verification.
    public let status: Status?

    /// The strategy pertaining to the parent sign-up or sign-in attempt.
    public let strategy: String?

    /// The number of attempts related to the verification.
    public let attempts: Int?

    /// The time the verification will expire at.
    public let expireAt: Date?

    /// The last error the verification attempt ran into.
    public let error: ClerkAPIError?

    /// The redirect URL for an external verification.
    public let externalVerificationRedirectUrl: String?

    /// The nonce pertaining to the verification.
    public let nonce: String?

    public init(
        status: Verification.Status? = nil,
        strategy: String? = nil,
        attempts: Int? = nil,
        expireAt: Date? = nil,
        error: ClerkAPIError? = nil,
        externalVerificationRedirectUrl: String? = nil,
        nonce: String? = nil
    ) {
        self.status = status
        self.strategy = strategy
        self.attempts = attempts
        self.expireAt = expireAt
        self.error = error
        self.externalVerificationRedirectUrl = externalVerificationRedirectUrl
        self.nonce = nonce
    }

    /// The state of the verification.
    public enum Status: String, Codable, Sendable {
        case unverified
        case verified
        case transferable
        case failed
        case expired

        case unknown

        public init(from decoder: Decoder) throws {
            self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
        }
    }
}

extension Verification {

    static var mockEmailCodeVerifiedVerification: Verification {
        Verification(
            status: .verified,
            strategy: "email_code",
            attempts: nil,
            expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
            error: nil,
            externalVerificationRedirectUrl: nil,
            nonce: nil
        )
    }

    static var mockEmailCodeUnverifiedVerification: Verification {
        Verification(
            status: .unverified,
            strategy: "email_code",
            attempts: nil,
            expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
            error: nil,
            externalVerificationRedirectUrl: nil,
            nonce: nil
        )
    }

    static var mockPhoneCodeVerifiedVerification: Verification {
        Verification(
            status: .verified,
            strategy: "phone_code",
            attempts: 0,
            expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
            error: nil,
            externalVerificationRedirectUrl: nil,
            nonce: nil
        )
    }

    static var mockPhoneCodeUnverifiedVerification: Verification {
        Verification(
            status: .unverified,
            strategy: "phone_code",
            attempts: 0,
            expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
            error: nil,
            externalVerificationRedirectUrl: nil,
            nonce: nil
        )
    }

    static var mockPasskeyVerifiedVerification: Verification {
        Verification(
            status: .verified,
            strategy: "passkey",
            attempts: 0,
            expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
            error: nil,
            externalVerificationRedirectUrl: nil,
            nonce: "12345"
        )
    }

    static var mockPasskeyUnverifiedVerification: Verification {
        Verification(
            status: .unverified,
            strategy: "passkey",
            attempts: 0,
            expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
            error: nil,
            externalVerificationRedirectUrl: nil,
            nonce: "12345"
        )
    }

    static var mockExternalAccountVerifiedVerification: Verification {
        Verification(
            status: .verified,
            strategy: "oauth_google",
            attempts: 0,
            expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
            error: nil,
            externalVerificationRedirectUrl: nil,
            nonce: nil
        )
    }

    static var mockExternalAccountUnverifiedVerification: Verification {
        Verification(
            status: .unverified,
            strategy: "oauth_google",
            attempts: 0,
            expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
            error: nil,
            externalVerificationRedirectUrl: "https://accounts.google.com",
            nonce: nil
        )
    }

}
