//
//  Organization.swift
//  Clerk
//
//  Created by Mike Pitre on 2/6/25.
//

import Foundation

/// The Organization object holds information about an organization, as well as methods for managing it.
public struct Organization: Codable, Equatable, Sendable, Hashable {
    
    /// The unique identifier of the related organization.
    public let id: String
    
    /// The name of the related organization.
    public let name: String
    
    /// The organization slug. If supplied, it must be unique for the instance.
    public let slug: String?
    
    /// Holds the organization logo or default logo. Compatible with Clerk's Image Optimization.
    public let imageUrl: String
    
    /// A getter boolean to check if the organization has an uploaded image.
    ///
    /// Returns false if Clerk is displaying an avatar for the organization.
    public let hasImage: Bool
    
    /// The number of members the associated organization contains.
    public let membersCount: Int
    
    /// The number of pending invitations to users to join the organization.
    public let pendingInvitationsCount: Int
    
    /// The maximum number of memberships allowed for the organization.
    public let maxAllowedMemberships: Int
    
    /// A getter boolean to check if the admin of the organization can delete it.
    public let adminDeleteEnabled: Bool
    
    /// The date when the organization was created.
    public let createdAt: Date
    
    /// The date when the organization was last updated.
    public let updatedAt: Date
    
    /// Metadata that can be read from the Frontend API and Backend API
    /// and can be set only from the Backend API.
    public let publicMetadata: JSON
}

