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

extension Organization {
    
    /// Updates an organization's attributes. Returns an Organization object.
    ///
    /// - Parameters:
    ///   - name: The organization name.
    ///   - slug: (Optional) The organization slug.
    @discardableResult @MainActor
    public func update(name: String, slug: String? = nil) async throws -> Organization {
        var request = ClerkFAPI.v1.organizations.id(id).patch
        request.query = [("_clerk_session_id", value: Clerk.shared.session?.id)]
        request.body = ["name": name, "slug": slug]
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Deletes the organization. Only administrators can delete an organization.
    ///
    /// Deleting an organization will also delete all memberships and invitations. This is **not reversible**.
    @discardableResult @MainActor
    public func destroy() async throws -> DeletedObject {
        var request = ClerkFAPI.v1.organizations.id(id).delete
        request.query = [("_clerk_session_id", Clerk.shared.session?.id)]
        return try await Clerk.shared.apiClient.send(request).value
    }
    
    /// Sets or replaces an organization's logo.
    ///
    /// The logo must be an image and its size cannot exceed 10MB.
    /// - Returns: ```Organization```
    @discardableResult @MainActor
    public func setLogo(_ imageData: Data) async throws -> Organization {
        
        let boundary = UUID().uuidString
        var data = Data()
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        data.append(imageData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        var request = ClerkFAPI.v1.organizations.id(id).logo.post
        request.headers = ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
        request.query = [("_clerk_session_id", value: Clerk.shared.session?.id)]
        return try await Clerk.shared.apiClient.upload(for: request, from: data).value.response
    }
    
    /// Returns a ClerkPaginatedResponse of RoleResource objects.
    ///
    /// - Parameters:
    ///     - initialPage: A number that can be used to skip the first n-1 pages. For example, if initialPage is set to 10, it is will skip the first 9 pages and will fetch the 10th page.
    ///     - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
    @discardableResult @MainActor
    public func getRoles(initialPage: Int = 0, pageSize: Int = 20) async throws -> ClerkPaginatedResponse<RoleResource> {
        var request = ClerkFAPI.v1.organizations.id(id).roles.get
        request.query = [("offset", String(initialPage)), ("limit", String(pageSize))]
        return try await Clerk.shared.apiClient.send(request).value
    }
    
}

