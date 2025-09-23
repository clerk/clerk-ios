//
//  OrganizationMembership.swift
//  Clerk
//
//  Created by Mike Pitre on 2/6/25.
//

import Foundation
import Get

/// The `OrganizationMembership` object is the model around an organization membership entity
/// and describes the relationship between users and organizations.
public struct OrganizationMembership: Codable, Equatable, Sendable, Hashable, Identifiable {

    /// The unique identifier for this organization membership.
    public let id: String

    /// Metadata that can be read from the Frontend API and Backend API
    /// and can be set only from the Backend API.
    public let publicMetadata: JSON

    /// The role of the current user in the organization.
    public let role: String

    /// The formatted role name associated with this organization membership.
    public let roleName: String

    /// The permissions associated with the role.
    public let permissions: [String]?

    /// Public information about the user that this membership belongs to.
    public let publicUserData: PublicUserData?

    /// The `Organization` object the membership belongs to.
    public let organization: Organization

    /// The date when the membership was created.
    public let createdAt: Date

    /// The date when the membership was last updated.
    public let updatedAt: Date

    public init(
        id: String,
        publicMetadata: JSON,
        role: String,
        roleName: String,
        permissions: [String]?,
        publicUserData: PublicUserData? = nil,
        organization: Organization,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.publicMetadata = publicMetadata
        self.role = role
        self.roleName = roleName
        self.permissions = permissions
        self.publicUserData = publicUserData
        self.organization = organization
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension OrganizationMembership {

    /// Deletes the membership from the organization it belongs to.
    ///
    /// - Returns: ``OrganizationMembership``
    /// - Throws: An error if the membership deletion fails.
    @discardableResult @MainActor
    public func destroy() async throws -> OrganizationMembership {
        guard let userId = publicUserData?.userId else {
            throw ClerkClientError(message: "Unable to delete membership: missing userId")
        }

        let request = Request<ClientResponse<OrganizationMembership>>(
            path: "/v1/organizations/\(organization.id)/memberships/\(userId)",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )

        return try await Clerk.shared.dependencyContainer.apiClient.send(request).value.response
    }

    /// Updates the member's role in the organization.
    ///
    /// - Parameter role: The role to assign to the member.
    /// - Throws: An error if the membership update fails.
    /// - Returns: ``OrganizationMembership``
    @discardableResult @MainActor
    public func update(role: String) async throws -> OrganizationMembership {
        guard let userId = publicUserData?.userId else {
            throw ClerkClientError(message: "Unable to update membership: missing userId")
        }

        let request = Request<ClientResponse<OrganizationMembership>>(
            path: "/v1/organizations/\(organization.id)/memberships/\(userId)",
            method: .patch,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "role": role
            ]
        )

        return try await Clerk.shared.dependencyContainer.apiClient.send(request).value.response
    }

}

extension OrganizationMembership {

    static var mockWithUserData: Self {
        .init(
            id: "1",
            publicMetadata: "{}",
            role: "org:role",
            roleName: "Member",
            permissions: ["org:sys_memberships:read"],
            publicUserData: .init(
                firstName: "First",
                lastName: "Last",
                imageUrl: "",
                hasImage: false,
                identifier: "identifier",
                userId: "1"
            ),
            organization: .mock,
            createdAt: Date.distantPast,
            updatedAt: .now
        )
    }

    static var mockWithoutUserData: Self {
        .init(
            id: "1",
            publicMetadata: "{}",
            role: "org:role",
            roleName: "Member",
            permissions: ["org:sys_memberships:read"],
            publicUserData: nil,
            organization: .mock,
            createdAt: Date.distantPast,
            updatedAt: .now
        )
    }

}
