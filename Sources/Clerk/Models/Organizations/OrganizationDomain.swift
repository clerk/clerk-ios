//
//  OrganizationDomain.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import Foundation

/// The model representing an organization domain.
public struct OrganizationDomain: Codable, Identifiable, Hashable, Sendable {
    
    /// The unique identifier for this organization domain.
    public let id: String
    
    /// The name for this organization domain (e.g. example.com).
    public let name: String
    
    /// The organization ID of the organization this domain is for.
    public let organizationId: String
    
    /// The enrollment mode for new users joining the organization.
    public let enrollmentMode: EnrollmentMode
    
    /// The object that describes the status of the verification process of the domain.
    public let verification: Verification
    
    /// The email address that was used to verify this organization domain, or `nil` if not available.
    public let affiliationEmailAddress: String?
    
    /// The number of total pending invitations sent to emails that match the domain name.
    public let totalPendingInvitations: Int
    
    /// The number of total pending suggestions sent to emails that match the domain name.
    public let totalPendingSuggestions: Int
    
    /// The date when the organization domain was created.
    public let createdAt: Date
    
    /// The date when the organization domain was last updated.
    public let updatedAt: Date
    
    /// The possible enrollment modes for an organization domain.
    public enum EnrollmentMode: String, Codable, CodingKeyRepresentable, Sendable {
        
        /// Users must be manually invited to join the organization.
        case manualInvitation
        
        /// During sign-up, a user will receive an invitation for the organization if their email's domain matches the verified domain.
        /// The user will join the organization if they accept the automatic invitation.
        case automaticInvitation
        
        /// During sign-up, a user will receive a suggestion for the organization if their email's domain matches the verified domain.
        /// The user can request to join, and an administrator must accept this request before the user can join the organization.
        case automaticSuggestion
        
        /// An unknown enrollment mode that acts as a fallback for unsupported or future cases.
        case unknown
        
        /// Initializes an `EnrollmentMode` from a decoder, defaulting to `.unknown` if the raw value is not recognized.
        public init(from decoder: Decoder) throws {
            self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
        }
    }
    
    /// The model representing the verification details of an organization domain.
    public struct Verification: Codable, Sendable, Hashable {
        
        /// The status of the verification process.
        public let status: VerificationStatus
        
        /// The strategy used for the verification process.
        public let strategy: VerificationStrategy
        
        /// The number of attempts that have occurred to verify the domain.
        ///
        /// This value tracks how many verification attempts have been made for this domain.
        public let attempts: Int
        
        /// The expiration date and time of the verification.
        ///
        /// Once the expiration date has passed, the verification process may need to be restarted.
        public let expiresAt: Date
        
        /// The possible statuses of the verification process.
        public enum VerificationStatus: String, Codable, CodingKeyRepresentable, Sendable {
            
            /// The domain has not been verified.
            case unverified
            
            /// The domain has been successfully verified.
            case verified
            
            /// An unknown verification status, used as a fallback for unsupported or future statuses.
            case unknown
            
            /// Initializes a `VerificationStatus` from a decoder, defaulting to `.unknown` if the raw value is not recognized.
            public init(from decoder: Decoder) throws {
                self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
            }
        }
        
        /// The strategy used for the domain verification process.
        public enum VerificationStrategy: String, Codable, CodingKeyRepresentable, Sendable {
            
            /// Verification was conducted via email code.
            case emailCode
            
            /// An unknown verification strategy, used as a fallback for unsupported or future strategies.
            case unknown
            
            /// Initializes a `VerificationStrategy` from a decoder, defaulting to `.unknown` if the raw value is not recognized.
            public init(from decoder: Decoder) throws {
                self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
            }
        }
    }
}
