//
//  Verification.swift
//
//
//  Created by Mike Pitre on 10/26/23.
//

import Foundation

/// The state of the verification process of a sign-in or sign-up attempt.
public class Verification: Decodable {
    
    public init(
        status: Verification.Status? = nil,
        strategy: Strategy? = nil,
        attempts: Int? = nil,
        expireAt: Date? = nil,
        error: ClerkAPIError? = nil,
        externalVerificationRedirectUrl: String? = nil
    ) {
        self.status = status
        self.strategy = strategy?.stringValue
        self.attempts = attempts
        self.expireAt = expireAt
        self.error = error
        self.externalVerificationRedirectUrl = externalVerificationRedirectUrl
    }
    
    /// The state of the verification.
    public let status: Status?
    
    /// The strategy pertaining to the parent sign-up or sign-in attempt.
    let strategy: String?
    
    /// The number of attempts related to the verification.
    let attempts: Int?
    
    /// The time the verification will expire at.
    let expireAt: Date?
    
    /// The last error the verification attempt ran into.
    let error: ClerkAPIError?
    
    /// The redirect URL for an external verification.
    public var externalVerificationRedirectUrl: String?
    
    public enum Status: String, Decodable, Equatable {
        case unverified
        case verified
        case transferable
        case failed
        case expired
    }
}

extension Verification: Equatable, Hashable {
    public static func == (lhs: Verification, rhs: Verification) -> Bool {
        lhs.status == rhs.status &&
        lhs.strategy == rhs.strategy &&
        lhs.attempts == rhs.attempts &&
        lhs.expireAt == rhs.expireAt &&
        lhs.error == rhs.error &&
        lhs.externalVerificationRedirectUrl == rhs.externalVerificationRedirectUrl
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(status)
        hasher.combine(strategy)
        hasher.combine(attempts)
        hasher.combine(expireAt)
        hasher.combine(error)
        hasher.combine(externalVerificationRedirectUrl)
    }
}

extension Verification {
    
    public var verificationStrategy: Strategy? {
        guard let strategy else { return nil }
        return .init(stringValue: strategy)
    }
    
}

public class SignUpVerification: Verification {
    let nextAction: String = ""
    let supportedStrategies: [String] = []
    
    var strategies: [Strategy] {
        supportedStrategies.compactMap({ .init(stringValue: $0) })
    }
}
