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
    public func update(
        name: String,
        slug: String? = nil
    ) async throws -> Organization {
        var request = ClerkFAPI.v1.organizations.id(id).patch
        request.body = [
            "name": name,
            "slug": slug
        ]
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Deletes the organization. Only administrators can delete an organization.
    ///
    /// Deleting an organization will also delete all memberships and invitations. This is **not reversible**.
    @discardableResult @MainActor
    public func destroy() async throws -> DeletedObject {
        var request = ClerkFAPI.v1.organizations.id(id).delete
        return try await Clerk.shared.apiClient.send(request).value
    }
    
    /// Sets or replaces an organization's logo.
    ///
    /// The logo must be an image and its size cannot exceed 10MB.
    /// - Returns: ``Organization``
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
        return try await Clerk.shared.apiClient.upload(for: request, from: data).value.response
    }
    
    /// Returns a ClerkPaginatedResponse of RoleResource objects.
    ///
    /// - Parameters:
    ///     - initialPage: A number that can be used to skip the first n-1 pages. For example, if initialPage is set to 10, it is will skip the first 9 pages and will fetch the 10th page.
    ///     - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
    /// - Returns:
    ///     A ``ClerkPaginatedResponse`` of ``RoleResource`` objects.
    @MainActor
    public func getRoles(
        initialPage: Int = 0,
        pageSize: Int = 20
    ) async throws -> ClerkPaginatedResponse<RoleResource> {
        var request = ClerkFAPI.v1.organizations.id(id).roles.get
        request.query = [
            ("offset", String(initialPage)),
            ("limit", String(pageSize))
        ]
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Retrieves the list of memberships for the currently active organization.
    ///
    /// - Parameters:
    ///     - query: Returns members that match the given query. For possible matches, we check for any of the user's identifier, usernames, user ids, first and last names. The query value doesn't need to match the exact value you are looking for, it is capable of partial matches as well.
    ///     - initialPage: A number that can be used to skip the first n-1 pages. For example, if initialPage is set to 10, it is will skip the first 9 pages and will fetch the 10th page.
    ///     - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
    ///
    /// - Returns:
    ///     A ``ClerkPaginatedResponse`` of ``OrganizationMembership`` objects.
    @MainActor
    public func getMemberships(
        query: String? = nil,
        initialPage: Int = 0,
        pageSize: Int = 20
    ) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
        var request = ClerkFAPI.v1.organizations.id(id).memberships.get
        request.query = [
            ("query", query),
            ("offset", String(initialPage)),
            ("limit", String(pageSize)),
            ("paginated", String(true))
        ]
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Adds a user as a member to an organization.
    ///
    /// A user can only be added to an organization if they are not already a member of it
    /// and if they already exist in the same instance as the organization.
    ///
    /// Only administrators can add members to an organization.
    ///
    /// - Parameters:
    ///   - userId: The ID of the user to be added as a member to the organization.
    ///   - role: The role that the user will have in the organization.
    ///
    /// - Returns:
    ///   An ``OrganizationMembership`` object.
    @discardableResult @MainActor
    public func addMember(
        userId: String,
        role: String
    ) async throws -> OrganizationMembership {
        var request = ClerkFAPI.v1.organizations.id(id).memberships.post
        request.query = [
            ("user_id", userId),
            ("role", role)
        ]
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Updates a member of an organization.
    ///
    /// Currently, only a user's role can be updated.
    ///
    /// - Parameters:
    ///   - userId: The ID of the user to update.
    ///   - role: The new role for the member.
    ///
    /// - Returns:
    ///   An ``OrganizationMembership`` object.
    @discardableResult @MainActor
    public func updateMember(
        userId: String,
        role: String
    ) async throws -> OrganizationMembership {
        var request = ClerkFAPI.v1.organizations.id(id).memberships.patch
        request.query = [
            ("user_id", userId),
            ("role", role)
        ]
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Removes a member from the organization based on the user ID.
    ///
    /// - Parameter userId:
    ///   The ID of the user to remove from the organization.
    ///
    /// - Returns:
    ///   An ``OrganizationMembership`` object.
    @discardableResult @MainActor
    public func removeMember(userId: String) async throws -> OrganizationMembership {
        var request = ClerkFAPI.v1.organizations.id(id).memberships.delete
        request.query = [("user_id", userId)]
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Retrieves the list of invitations for the currently active organization.
    ///
    /// - Parameters:
    ///   - initialPage: A number that can be used to skip the first n-1 pages.
    ///     For example, if `initialPage` is set to 10, it will skip the first 9 pages and fetch the 10th page.
    ///   - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
    ///   - status: The status an invitation can have.
    ///
    /// - Returns:
    ///   A ``ClerkPaginatedResponse`` of ``OrganizationInvitation`` objects.
    @MainActor
    public func getInvitations(
        initialPage: Int = 0,
        pageSize: Int = 20,
        status: String? = nil
    ) async throws -> ClerkPaginatedResponse<OrganizationInvitation> {
        var request = ClerkFAPI.v1.organizations.id(id).invitations.get
        request.query = [
            ("offset", String(initialPage)),
            ("limit", String(pageSize)),
            ("status", status)
        ]
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Creates and sends an invitation to the target email address to become a member with the specified role.
    ///
    /// - Parameters:
    ///   - emailAddress: The email address to invite.
    ///   - role: The role of the new member.
    ///
    /// - Returns:
    ///   An ``OrganizationInvitation`` object.
    @discardableResult @MainActor
    public func inviteMember(
        emailAddress: String,
        role: String
    ) async throws -> OrganizationInvitation {
        var request = ClerkFAPI.v1.organizations.id(id).invitations.post
        request.body = [
            "email_address": emailAddress,
            "role": role
        ]
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Creates and sends an invitation to the target email addresses for becoming a member with the role passed in the parameters.
    ///
    /// - Parameters:
    ///   - params: ``InviteMembersParams``
    ///
    /// - Returns:
    ///   An array of ``OrganizationInvitation`` objects.
    @discardableResult @MainActor
    public func inviteMembers(params: InviteMembersParams) async throws -> [OrganizationInvitation] {
        var request = ClerkFAPI.v1.organizations.id(id).invitations.bulk.post
        request.body = params
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Creates a new domain for the currently active organization.
    ///
    /// - Parameters:
    ///   - domainName: The domain name that will be added to the organization.
    /// - Returns: An ``OrganizationDomain`` object.
    @discardableResult @MainActor
    public func createDomain(domainName: String) async throws -> OrganizationDomain {
        var request = ClerkFAPI.v1.organizations.id(id).domains.post
        request.body = ["name": domainName]
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Retrieves the list of domains for the currently active organization.
    ///
    /// Returns a `ClerkPaginatedResponse` of `OrganizationDomain` objects.
    ///
    /// - Parameters:
    ///   - initialPage: A number that can be used to skip the first n-1 pages.
    ///                  For example, if `initialPage` is set to 10, it will skip the first 9 pages and fetch the 10th page.
    ///   - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
    ///
    /// - Returns: A ``ClerkPaginatedResponse`` of ``OrganizationDomain`` objects.
    @MainActor
    public func getDomains(
        initialPage: Int = 0,
        pageSize: Int = 20
    ) async throws -> ClerkPaginatedResponse<OrganizationDomain> {
        var request = ClerkFAPI.v1.organizations.id(id).domains.get
        request.query = [
            ("offset", String(initialPage)),
            ("limit", String(pageSize))
        ]
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Retrieves a domain for an organization based on the given domain ID.
    ///
    /// - Parameters:
    ///   - domainId: The ID of the domain that will be fetched.
    /// - Returns: An ``OrganizationDomain`` object.
    @MainActor
    public func getDomain(domainId: String) async throws -> OrganizationDomain {
        var request = ClerkFAPI.v1.organizations.id(id).domains.id(domainId).get
        return try await Clerk.shared.apiClient.send(request).value.response
    }
    
    /// Retrieves the list of membership requests for the currently active organization.
    ///
    /// - Parameters:
    ///   - initialPage: A number that can be used to skip the first n-1 pages.
    ///                  For example, if `initialPage` is set to 10, it will skip the first 9 pages and fetch the 10th page.
    ///   - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
    ///   - status: The status of the membership requests that will be included in the response.
    /// - Returns: A ``ClerkPaginatedResponse`` of ``OrganizationMembershipRequest`` objects.
    @MainActor
    public func getMembershipRequests(
        initialPage: Int = 0,
        pageSize: Int = 20,
        status: String? = nil
    ) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest> {
        var request = ClerkFAPI.v1.organizations.id(id).membershipRequests.get
        request.query = [
            ("offset", String(initialPage)),
            ("limit", String(pageSize)),
            ("status", status)
        ]
        return try await Clerk.shared.apiClient.send(request).value.response
    }
}

