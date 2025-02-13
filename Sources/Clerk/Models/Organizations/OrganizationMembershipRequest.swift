//
//  OrganizationMembershipRequest.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import Foundation
import Get

/// The model that describes the request of a user to join an organization.
public struct OrganizationMembershipRequest: Codable, Sendable, Hashable, Identifiable {
    
    /// The unique identifier for this membership request.
    public let id: String
    
    /// The organization ID of the organization this request is for.
    public let organizationId: String
    
    /// The status of the request.
    public let status: Status
    
    /// Public information about the user that this request belongs to.
    public let publicUserData: PublicUserData?
    
    /// The date when the membership request was created.
    public let createdAt: Date
    
    /// The date when the membership request was last updated.
    public let updatedAt: Date
    
    /// The possible statuses for a membership request.
    public enum Status: String, Codable, Sendable, CodingKeyRepresentable {
        
        /// The membership request is pending and awaiting approval.
        case pending
        
        /// The membership request has been accepted, and the user has joined the organization.
        case accepted
        
        /// The membership request has been revoked and is no longer valid.
        case revoked
        
        /// An unknown status, used as a fallback for unexpected or unsupported values during decoding.
        case unknown
        
        /// Initializes a `Status` instance from a decoder.
        /// If the raw value cannot be matched to a known status, the `unknown` case is used as a fallback.
        public init(from decoder: Decoder) throws {
            self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
        }
    }
}

extension OrganizationMembershipRequest {
        
    /// Accepts the request of a user to join the organization the request refers to.
    @discardableResult @MainActor
    public func accept() async throws -> OrganizationMembershipRequest {
        let request = Request<ClientResponse<OrganizationMembershipRequest>>(
            path: "/organizations/\(organizationId)/membership_requests/\(id)/accept",
            method: .post
        )
        
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Rejects the request of a user to join the organization the request refers to.
    @discardableResult @MainActor
    public func reject() async throws -> OrganizationMembershipRequest {
        let request = Request<ClientResponse<OrganizationMembershipRequest>>(
            path: "/organizations/\(organizationId)/membership_requests/\(id)/reject",
            method: .post
        )
        
        return try await Clerk.shared.apiClient.send(request).value.response
    }
}
