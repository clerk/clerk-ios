//
//  Verification.swift
//
//
//  Created by Mike Pitre on 10/26/23.
//

import Foundation

/// The state of the verification process of a sign-in or sign-up attempt.
public struct Verification: Codable, Equatable, Hashable {
    
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
    public var externalVerificationRedirectUrl: String?
    
    public var nextAction: NextAction?
    
    public var supportedStrategies: [String]?
    
    public var strategyEnum: Strategy? {
        if let strategy { return Strategy(stringValue: strategy) }
        return nil
    }
    
    public var supportedStrategiesEnums: [Strategy]? {
        supportedStrategies?.compactMap { Strategy(stringValue: $0) }
    }
    
    /// The state of the verification.
    public enum Status: String, Codable {
        case unverified
        case verified
        case transferable
        case failed
        case expired
    }
    
    public enum NextAction: String, Codable {
        case needsPrepare = "needs_prepare"
        case needsAttempt = "needs_attempt"
        case empty = ""
    }
}
