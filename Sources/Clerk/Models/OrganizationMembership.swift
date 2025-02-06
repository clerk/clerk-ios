//
//  OrganizationMembership.swift
//  Clerk
//
//  Created by Mike Pitre on 2/6/25.
//

import Foundation

/// The `OrganizationMembership` object is the model around an organization membership entity
/// and describes the relationship between users and organizations.
public struct OrganizationMembership: Codable, Equatable, Sendable, Hashable {
    
    /// The unique identifier for this organization membership.
    public let id: String
    
    /// Metadata that can be read from the Frontend API and Backend API
    /// and can be set only from the Backend API.
    public let publicMetadata: JSON
    
    /// The role of the current user in the organization.
    public let role: String
    
    /// The `Organization` object the membership belongs to.
    public let organization: Organization
    
    /// The date when the membership was created.
    public let createdAt: Date
    
    /// The date when the membership was last updated.
    public let updatedAt: Date
}

