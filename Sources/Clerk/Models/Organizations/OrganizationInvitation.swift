//
//  OrganizationInvitation.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import Foundation

/// Represents an organization invitation and its associated details.
public struct OrganizationInvitation: Codable, Sendable, Hashable, Identifiable {
    
    /// The unique identifier for this organization invitation.
    public let id: String
    
    /// The email address the invitation has been sent to.
    public let emailAddress: String
    
    /// The organization ID of the organization this invitation is for.
    public let organizationId: String
    
    /// Metadata that can be read from the Frontend API and Backend API and can be set only from the Backend API.
    public let publicMetadata: JSON
    
    /// The role of the user in the organization.
    ///
    /// Clerk provides the default roles org:admin and org:member. However, you can create custom roles as well.
    public let role: String
    
    /// The status of the invitation.
    public let status: InvitationStatus
    
    /// The date when the invitation was created.
    public let createdAt: Date
    
    /// The date when the invitation was last updated.
    public let updatedAt: Date
    
    /// Represents the possible statuses of an organization invitation.
    public enum InvitationStatus: String, Codable, CodingKeyRepresentable, Sendable {
        /// The invitation has been sent but not yet responded to.
        case pending
        
        /// The invitation has been accepted by the recipient.
        case accepted
        
        /// The invitation has been revoked by the organization.
        case revoked
        
        /// A fallback value used when the status received from the backend is unrecognized.
        case unknown
        
        /// Initializes an `InvitationStatus` from a decoder.
        ///
        /// If the raw value from the decoder does not match any of the known cases, the `unknown` case will be used as a fallback.
        ///
        /// - Parameter decoder: The decoder to decode the raw value from.
        /// - Throws: An error if the decoding process fails.
        public init(from decoder: Decoder) throws {
            self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
        }
    }
}

extension OrganizationInvitation {
    
    /// Revokes the invitation for the email it corresponds to.
    @discardableResult @MainActor
    public func revoke() async throws -> OrganizationInvitation {
        let request = ClerkFAPI.v1.organizations.id(organizationId).invitations.id(id).revoke.post
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
}
