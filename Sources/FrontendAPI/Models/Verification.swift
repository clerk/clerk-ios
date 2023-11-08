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
    
    private enum CodingKeys: String, CodingKey {
        case status
        case strategy
        case attempts
        case expireAt = "expire_at"
        case error
        case externalVerificationRedirectUrl = "external_verification_redirect_url"
    }
    
    required public init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<Verification.CodingKeys> = try decoder.container(keyedBy: Verification.CodingKeys.self)
        
        self.status = try container.decodeIfPresent(Verification.Status.self, forKey: Verification.CodingKeys.status)
        self.strategy = try container.decodeIfPresent(String.self, forKey: Verification.CodingKeys.strategy)
        self.attempts = try container.decodeIfPresent(Int.self, forKey: Verification.CodingKeys.attempts)
        self.expireAt = try container.decodeIfPresent(Date.self, forKey: Verification.CodingKeys.expireAt)
        self.error = try container.decodeIfPresent(ClerkAPIError.self, forKey: Verification.CodingKeys.error)
        self.externalVerificationRedirectUrl = try container.decodeIfPresent(String.self, forKey: Verification.CodingKeys.externalVerificationRedirectUrl)
        
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
    public init(
        status: Verification.Status? = nil,
        strategy: Strategy? = nil,
        attempts: Int? = nil,
        expireAt: Date? = nil,
        error: ClerkAPIError? = nil,
        externalVerificationRedirectUrl: String? = nil,
        nextAction: String = "",
        supportedStrategies: [String] = []
    ) {
        self.nextAction = nextAction
        self.supportedStrategies = supportedStrategies
        super.init(
            status: status,
            strategy: strategy,
            attempts: attempts,
            expireAt: expireAt,
            error: error,
            externalVerificationRedirectUrl: externalVerificationRedirectUrl
        )
    }
    
    private enum CodingKeys: String, CodingKey {
        case nextAction = "next_action"
        case supportedStrategies = "supported_strategies"
    }
       
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.nextAction = try container.decode(String.self, forKey: .nextAction)
        self.supportedStrategies = try container.decode([String].self, forKey: .supportedStrategies)
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    var nextAction: String = ""
    var supportedStrategies: [String] = []
    
    var strategies: [Strategy] {
        supportedStrategies.compactMap({ .init(stringValue: $0) })
    }
}
