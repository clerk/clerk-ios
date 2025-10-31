//
//  Organization.swift
//  Clerk
//
//  Created by Mike Pitre on 2/6/25.
//

import FactoryKit
import Foundation

/// The Organization object holds information about an organization, as well as methods for managing it.
public struct Organization: Codable, Equatable, Sendable, Hashable, Identifiable {

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
    public let membersCount: Int?

    /// The number of pending invitations to users to join the organization.
    public let pendingInvitationsCount: Int?

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
    public let publicMetadata: JSON?

    public init(
        id: String,
        name: String,
        slug: String? = nil,
        imageUrl: String,
        hasImage: Bool,
        membersCount: Int? = nil,
        pendingInvitationsCount: Int? = nil,
        maxAllowedMemberships: Int,
        adminDeleteEnabled: Bool,
        createdAt: Date,
        updatedAt: Date,
        publicMetadata: JSON? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.imageUrl = imageUrl
        self.hasImage = hasImage
        self.membersCount = membersCount
        self.pendingInvitationsCount = pendingInvitationsCount
        self.maxAllowedMemberships = maxAllowedMemberships
        self.adminDeleteEnabled = adminDeleteEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.publicMetadata = publicMetadata
    }
}

extension Organization {

    private var organizationService: any OrganizationServiceProtocol { Container.shared.organizationService() }

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
        try await organizationService.updateOrganization(id, name, slug)
    }

    /// Deletes the organization. Only administrators can delete an organization.
    ///
    /// Deleting an organization will also delete all memberships and invitations. This is **not reversible**.
    @discardableResult @MainActor
    public func destroy() async throws -> DeletedObject {
        try await organizationService.destroyOrganization(id)
    }

    /// Sets or replaces an organization's logo.
    ///
    /// The logo must be an image and its size cannot exceed 10MB.
    /// - Returns: ``Organization``
    @discardableResult @MainActor
    public func setLogo(imageData: Data) async throws -> Organization {
        try await organizationService.setOrganizationLogo(id, imageData)
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
        try await organizationService.getOrganizationRoles(id, initialPage, pageSize)
    }

    /// Retrieves the list of memberships for the currently active organization.
    ///
    /// - Parameters:
    ///     - query: Returns members that match the given query. For possible matches, we check for any of the user's identifier, usernames, user ids, first and last names. The query value doesn't need to match the exact value you are looking for, it is capable of partial matches as well.
    ///     - role: Filter by roles. This can be one of the predefined roles or a custom role.
    ///     - initialPage: A number that can be used to skip the first n-1 pages. For example, if initialPage is set to 10, it is will skip the first 9 pages and will fetch the 10th page.
    ///     - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
    ///
    /// - Returns:
    ///     A ``ClerkPaginatedResponse`` of ``OrganizationMembership`` objects.
    @MainActor
    public func getMemberships(
        query: String? = nil,
        role: [String]? = nil,
        initialPage: Int = 0,
        pageSize: Int = 20
    ) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
        try await organizationService.getOrganizationMemberships(id, query, role, initialPage, pageSize)
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
        try await organizationService.addOrganizationMember(id, userId, role)
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
        try await organizationService.updateOrganizationMember(id, userId, role)
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
        try await organizationService.removeOrganizationMember(id, userId)
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
        try await organizationService.getOrganizationInvitations(id, initialPage, pageSize, status)
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
        try await organizationService.inviteOrganizationMember(id, emailAddress, role)
    }

    //    /// Creates and sends an invitation to the target email addresses for becoming a member with the role passed in the parameters.
    //    ///
    //    /// - Parameters:
    //    ///   - params: ``InviteMembersParams``
    //    ///
    //    /// - Returns:
    //    ///   An array of ``OrganizationInvitation`` objects.
    //    @discardableResult @MainActor
    //    public func inviteMembers(params: InviteMembersParams) async throws -> [OrganizationInvitation] {
    //        let request = Request<ClientResponse<[OrganizationInvitation]>>(
    //            path: "/v1/organizations/\(id)/invitations/bulk",
    //            method: .post,
    //            query: [("_clerk_session_id", Clerk.shared.session?.id)],
    //            body: params
    //        )
    //        return try await Container.shared.apiClient().send(request).value.response
    //    }

    /// Creates a new domain for the currently active organization.
    ///
    /// - Parameters:
    ///   - domainName: The domain name that will be added to the organization.
    /// - Returns: An ``OrganizationDomain`` object.
    @discardableResult @MainActor
    public func createDomain(domainName: String) async throws -> OrganizationDomain {
        try await organizationService.createOrganizationDomain(id, domainName)
    }

    /// Retrieves the list of domains for the currently active organization.
    ///
    /// Returns a `ClerkPaginatedResponse` of `OrganizationDomain` objects.
    ///
    /// - Parameters:
    ///  - initialPage: A number that can be used to skip the first n-1 pages.
    ///                 For example, if `initialPage` is set to 10, it will skip the first 9 pages and fetch the 10th page.
    ///  - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
    ///  - enrollmentMode: An enrollment mode will change how new users join an organization.
    /// - Returns: A ``ClerkPaginatedResponse`` of ``OrganizationDomain`` objects.
    @MainActor
    public func getDomains(
        initialPage: Int = 0,
        pageSize: Int = 20,
        enrollmentMode: String? = nil
    ) async throws -> ClerkPaginatedResponse<OrganizationDomain> {
        try await organizationService.getOrganizationDomains(id, initialPage, pageSize, enrollmentMode)
    }

    /// Retrieves a domain for an organization based on the given domain ID.
    ///
    /// - Parameters:
    ///   - domainId: The ID of the domain that will be fetched.
    /// - Returns: An ``OrganizationDomain`` object.
    @MainActor
    public func getDomain(domainId: String) async throws -> OrganizationDomain {
        try await organizationService.getOrganizationDomain(id, domainId)
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
        try await organizationService.getOrganizationMembershipRequests(id, initialPage, pageSize, status)
    }
}

extension Organization {

    package static var mock: Self {
        .init(
            id: "1",
            name: "Organization Name",
            slug: "org-slug",
            imageUrl: "",
            hasImage: false,
            membersCount: 3,
            pendingInvitationsCount: 1,
            maxAllowedMemberships: 100,
            adminDeleteEnabled: true,
            createdAt: Date.distantPast,
            updatedAt: .now,
            publicMetadata: nil
        )
    }

}
