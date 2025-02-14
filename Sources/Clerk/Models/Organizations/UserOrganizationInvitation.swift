//
//  UserOrganizationInvitation.swift
//  Clerk
//
//  Created by Mike Pitre on 2/13/25.
//

import Foundation

/// The `UserOrganizationInvitation` object is the model around a user's invitation to an organization.
public struct UserOrganizationInvitation: Codable, Sendable {
    
    /// The unique identifier for this organization invitation.
    public let id: String
    
    /// The email address the invitation has been sent to.
    public let emailAddress: String
    
    /// The public data of the organization.
    public let publicOrganizationData: PublicOrganizationData
    
    /// The public metadata of the organization invitation.
    public let publicMetadata: JSON
    
    /// The role of the current user in the organization.
    /// - Note: This is a string that represents the user's role. Clerk provides the default roles `org:admin` and `org:member`, but custom roles can also be used.
    public let role: String
    
    /// The status of the invitation.
    /// - Possible values: `pending`, `accepted`, `revoked`.
    public let status: String
    
    /// The date when the invitation was created.
    public let createdAt: Date
    
    /// The date when the invitation was last updated.
    public let updatedAt: Date
    
}

/// The public data of the organization.
public struct PublicOrganizationData: Codable, Sendable {
    /// Whether the organization has an image.
    public let hasImage: Bool
    /// Holds the organization logo. Compatible with Clerk's Image Optimization.
    public let imageUrl: String
    /// The name of the organization.
    public let name: String
    /// The ID of the organization.
    public let id: String
    /// The slug of the organization.
    public let slug: String?
}
