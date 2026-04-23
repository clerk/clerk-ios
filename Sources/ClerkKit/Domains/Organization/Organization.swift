//
//  Organization.swift
//  Clerk
//

import Foundation

/// The Organization object holds information about an organization, as well as methods for managing it.
public struct Organization: Codable, Equatable, Sendable, Identifiable {
  /// The unique identifier of the related organization.
  public var id: String

  /// The name of the related organization.
  public var name: String

  /// The organization slug. If supplied, it must be unique for the instance.
  public var slug: String?

  /// Holds the organization logo or default logo. Compatible with Clerk's Image Optimization.
  public var imageUrl: String

  /// A getter boolean to check if the organization has an uploaded image.
  ///
  /// Returns false if Clerk is displaying an avatar for the organization.
  public var hasImage: Bool

  /// The number of members the associated organization contains.
  public var membersCount: Int?

  /// The number of pending invitations to users to join the organization.
  public var pendingInvitationsCount: Int?

  /// The maximum number of memberships allowed for the organization.
  public var maxAllowedMemberships: Int

  /// A getter boolean to check if the admin of the organization can delete it.
  public var adminDeleteEnabled: Bool

  /// The date when the organization was created.
  public var createdAt: Date

  /// The date when the organization was last updated.
  public var updatedAt: Date

  /// Metadata that can be read from the Frontend API and Backend API
  /// and can be set only from the Backend API.
  public var publicMetadata: JSON?

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
    try await Clerk.shared.organizations.update(self, name: name, slug: slug)
  }

  /// Deletes the organization. Only administrators can delete an organization.
  ///
  /// Deleting an organization will also delete all memberships and invitations. This is **not reversible**.
  @discardableResult @MainActor
  public func destroy() async throws -> DeletedObject {
    try await Clerk.shared.organizations.destroy(self)
  }

  /// Sets or replaces an organization's logo.
  ///
  /// The logo must be an image and its size cannot exceed 10MB.
  /// - Returns: ``Organization``
  @discardableResult @MainActor
  public func setLogo(imageData: Data) async throws -> Organization {
    try await Clerk.shared.organizations.setLogo(for: self, imageData: imageData)
  }

  /// Returns a ClerkPaginatedResponse of RoleResource objects.
  ///
  /// - Parameters:
  ///     - page: The 1-based page number to fetch. Defaults to `1`.
  ///     - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
  /// - Returns:
  ///     A ``ClerkPaginatedResponse`` of ``RoleResource`` objects.
  @MainActor
  public func getRoles(
    page: Int = 1,
    pageSize: Int = 20
  ) async throws -> ClerkPaginatedResponse<RoleResource> {
    try await Clerk.shared.organizations.getRoles(for: self, page: page, pageSize: pageSize)
  }

  /// Retrieves the list of memberships for the currently active organization.
  ///
  /// - Parameters:
  ///     - query: Returns members that match the given query. For possible matches, we check for any of the user's identifier, usernames, user ids, first and last names. The query value doesn't need to match the exact value you are looking for, it is capable of partial matches as well.
  ///     - role: Filter by roles. This can be one of the predefined roles or a custom role.
  ///     - page: The 1-based page number to fetch. Defaults to `1`.
  ///     - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
  ///
  /// - Returns:
  ///     A ``ClerkPaginatedResponse`` of ``OrganizationMembership`` objects.
  @MainActor
  public func getMemberships(
    query: String? = nil,
    role: [String]? = nil,
    page: Int = 1,
    pageSize: Int = 20
  ) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    try await Clerk.shared.organizations.getMemberships(
      for: self,
      query: query,
      role: role,
      page: page,
      pageSize: pageSize
    )
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
    try await Clerk.shared.organizations.addMember(to: self, userId: userId, role: role)
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
    try await Clerk.shared.organizations.updateMember(in: self, userId: userId, role: role)
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
    try await Clerk.shared.organizations.removeMember(from: self, userId: userId)
  }

  /// Retrieves the list of invitations for the currently active organization.
  ///
  /// - Parameters:
  ///   - page: The 1-based page number to fetch. Defaults to `1`.
  ///   - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
  ///   - status: The status an invitation can have.
  ///
  /// - Returns:
  ///   A ``ClerkPaginatedResponse`` of ``OrganizationInvitation`` objects.
  @MainActor
  public func getInvitations(
    page: Int = 1,
    pageSize: Int = 20,
    status: String? = nil
  ) async throws -> ClerkPaginatedResponse<OrganizationInvitation> {
    try await Clerk.shared.organizations.getInvitations(
      for: self,
      page: page,
      pageSize: pageSize,
      status: status
    )
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
    try await Clerk.shared.organizations.inviteMember(to: self, emailAddress: emailAddress, role: role)
  }

  /// Creates a new domain for the currently active organization.
  ///
  /// - Parameters:
  ///   - domainName: The domain name that will be added to the organization.
  /// - Returns: An ``OrganizationDomain`` object.
  @discardableResult @MainActor
  public func createDomain(domainName: String) async throws -> OrganizationDomain {
    try await Clerk.shared.organizations.createDomain(for: self, domainName: domainName)
  }

  /// Retrieves the list of domains for the currently active organization.
  ///
  /// Returns a `ClerkPaginatedResponse` of `OrganizationDomain` objects.
  ///
  /// - Parameters:
  ///  - page: The 1-based page number to fetch. Defaults to `1`.
  ///  - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
  ///  - enrollmentMode: An enrollment mode will change how new users join an organization.
  /// - Returns: A ``ClerkPaginatedResponse`` of ``OrganizationDomain`` objects.
  @MainActor
  public func getDomains(
    page: Int = 1,
    pageSize: Int = 20,
    enrollmentMode: String? = nil
  ) async throws -> ClerkPaginatedResponse<OrganizationDomain> {
    try await Clerk.shared.organizations.getDomains(
      for: self,
      page: page,
      pageSize: pageSize,
      enrollmentMode: enrollmentMode
    )
  }

  /// Retrieves a domain for an organization based on the given domain ID.
  ///
  /// - Parameters:
  ///   - domainId: The ID of the domain that will be fetched.
  /// - Returns: An ``OrganizationDomain`` object.
  @MainActor
  public func getDomain(domainId: String) async throws -> OrganizationDomain {
    try await Clerk.shared.organizations.getDomain(for: self, domainId: domainId)
  }

  /// Retrieves the list of membership requests for the currently active organization.
  ///
  /// - Parameters:
  ///   - page: The 1-based page number to fetch. Defaults to `1`.
  ///   - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
  ///   - status: The status of the membership requests that will be included in the response.
  /// - Returns: A ``ClerkPaginatedResponse`` of ``OrganizationMembershipRequest`` objects.
  @MainActor
  public func getMembershipRequests(
    page: Int = 1,
    pageSize: Int = 20,
    status: String? = nil
  ) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest> {
    try await Clerk.shared.organizations.getMembershipRequests(
      for: self,
      page: page,
      pageSize: pageSize,
      status: status
    )
  }
}
