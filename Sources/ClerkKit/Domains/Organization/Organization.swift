//
//  Organization.swift
//  Clerk
//

import ClerkSnapshots
import Foundation

/// The Organization object holds information about an organization, as well as methods for managing it.
public typealias Organization = ClerkSnapshots.Organization

extension Organization: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

extension Organization {
  @MainActor
  private var organizationService: any OrganizationServiceProtocol {
    Clerk.shared.dependencies.organizationService
  }

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
    try await js(OrganizationJSCall.update(UpdateOrganizationParams(name: name, slug: slug)), as: Organization.self)
  }

  /// Deletes the organization. Only administrators can delete an organization.
  ///
  /// Deleting an organization will also delete all memberships and invitations. This is **not reversible**.
  @discardableResult @MainActor
  public func destroy() async throws -> DeletedObject {
    try await js(OrganizationJSCall.destroy, as: DeletedObject.self)
  }

  /// Sets or replaces an organization's logo.
  ///
  /// The logo must be an image and its size cannot exceed 10MB.
  /// - Returns: ``Organization``
  @discardableResult @MainActor
  public func setLogo(imageData: Data) async throws -> Organization {
    try await organizationService.setOrganizationLogo(organizationId: id, imageData: imageData)
  }

  /// Deletes the organization's uploaded logo and falls back to the default logo.
  ///
  /// - Returns: ``DeletedObject``
  @discardableResult @MainActor
  public func deleteLogo() async throws -> DeletedObject {
    try await organizationService.deleteOrganizationLogo(organizationId: id)
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
    try await js(
      OrganizationJSCall.getRoles(GetRolesParams(initialPage: page, pageSize: pageSize)),
      as: ClerkPaginatedResponse<RoleResource>.self
    )
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
    try await memberships(query: query, role: role, page: page, pageSize: pageSize)
  }

  /// Retrieves the list of memberships for the currently active organization.
  ///
  /// - Parameters:
  ///     - query: Returns members that match the given query.
  ///     - role: Filter by roles. This can be one of the predefined roles or a custom role.
  ///     - offset: The number of items to skip before returning results.
  ///     - pageSize: A number that indicates the maximum number of results that should be returned.
  ///
  /// - Returns:
  ///     A ``ClerkPaginatedResponse`` of ``OrganizationMembership`` objects.
  @MainActor
  package func getMemberships(
    query: String? = nil,
    role: [String]? = nil,
    offset: Int,
    pageSize: Int = 10
  ) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    try await memberships(
      query: query,
      role: role,
      page: page(fromOffset: offset, pageSize: pageSize),
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
    try await js(OrganizationJSCall.addMember(AddMemberParams(userId: userId, role: role)), as: OrganizationMembership.self)
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
    try await js(
      OrganizationJSCall.updateMember(UpdateMembershipParams(userId: userId, role: role)),
      as: OrganizationMembership.self
    )
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
    try await js(OrganizationJSCall.removeMember(userId: userId), as: OrganizationMembership.self)
  }

  /// Retrieves the list of invitations for the currently active organization.
  ///
  /// - Parameters:
  ///   - page: The 1-based page number to fetch. Defaults to `1`.
  ///   - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
  ///   - status: An array of invitation statuses to filter by. Defaults to an empty array, which applies no status filter.
  ///
  /// - Returns:
  ///   A ``ClerkPaginatedResponse`` of ``OrganizationInvitation`` objects.
  @MainActor
  public func getInvitations(
    page: Int = 1,
    pageSize: Int = 20,
    status: [String] = []
  ) async throws -> ClerkPaginatedResponse<OrganizationInvitation> {
    try await invitations(page: page, pageSize: pageSize, status: status)
  }

  /// Retrieves the list of invitations for the currently active organization.
  ///
  /// - Parameters:
  ///   - offset: The number of items to skip before returning results.
  ///   - pageSize: A number that indicates the maximum number of results that should be returned.
  ///   - status: An array of invitation statuses to filter by. Defaults to an empty array, which applies no status filter.
  ///
  /// - Returns:
  ///   A ``ClerkPaginatedResponse`` of ``OrganizationInvitation`` objects.
  @MainActor
  package func getInvitations(
    offset: Int,
    pageSize: Int = 10,
    status: [String] = []
  ) async throws -> ClerkPaginatedResponse<OrganizationInvitation> {
    try await invitations(
      page: page(fromOffset: offset, pageSize: pageSize),
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
    try await js(
      OrganizationJSCall.inviteMember(InviteMemberParams(emailAddress: emailAddress, role: role)),
      as: OrganizationInvitation.self
    )
  }

  /// Creates and sends invitations to the target email addresses to become members with the specified role.
  ///
  /// - Parameters:
  ///   - emailAddresses: The email addresses to invite.
  ///   - role: The role of the new members.
  ///
  /// - Returns:
  ///   An array of ``OrganizationInvitation`` objects.
  @discardableResult @MainActor
  public func inviteMembers(
    emailAddresses: [String],
    role: String
  ) async throws -> [OrganizationInvitation] {
    try await js(
      OrganizationJSCall.inviteMembers(InviteMembersParams(emailAddresses: emailAddresses, role: role)),
      as: [OrganizationInvitation].self
    )
  }

  /// Creates a new domain for the currently active organization.
  ///
  /// - Parameters:
  ///   - domainName: The domain name that will be added to the organization.
  /// - Returns: An ``OrganizationDomain`` object.
  @discardableResult @MainActor
  public func createDomain(domainName: String) async throws -> OrganizationDomain {
    try await js(OrganizationJSCall.createDomain(domainName: domainName, params: nil), as: OrganizationDomain.self)
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
    enrollmentMode: OrganizationDomain.EnrollmentMode? = nil
  ) async throws -> ClerkPaginatedResponse<OrganizationDomain> {
    try await domains(page: page, pageSize: pageSize, enrollmentMode: enrollmentMode?.rawValue)
  }

  /// Retrieves the list of domains for the currently active organization.
  ///
  /// - Parameters:
  ///  - offset: The number of items to skip before returning results.
  ///  - pageSize: A number that indicates the maximum number of results that should be returned.
  ///  - enrollmentMode: An enrollment mode will change how new users join an organization.
  /// - Returns: A ``ClerkPaginatedResponse`` of ``OrganizationDomain`` objects.
  @MainActor
  package func getDomains(
    offset: Int,
    pageSize: Int = 10,
    enrollmentMode: String? = nil
  ) async throws -> ClerkPaginatedResponse<OrganizationDomain> {
    try await domains(
      page: page(fromOffset: offset, pageSize: pageSize),
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
    try await js(OrganizationJSCall.getDomain(OrganizationGetDomain_0(domainId: domainId)), as: OrganizationDomain.self)
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
    try await membershipRequests(page: page, pageSize: pageSize, status: status)
  }

  /// Retrieves the list of membership requests for the currently active organization.
  ///
  /// - Parameters:
  ///   - offset: The number of items to skip before returning results.
  ///   - pageSize: A number that indicates the maximum number of results that should be returned.
  ///   - status: The status of the membership requests that will be included in the response.
  /// - Returns: A ``ClerkPaginatedResponse`` of ``OrganizationMembershipRequest`` objects.
  @MainActor
  package func getMembershipRequests(
    offset: Int,
    pageSize: Int = 10,
    status: String? = nil
  ) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest> {
    try await membershipRequests(
      page: page(fromOffset: offset, pageSize: pageSize),
      pageSize: pageSize,
      status: status
    )
  }

  @MainActor
  public func getPaymentMethods(params: ClerkKit.GetPaymentMethodsParams? = nil) async throws -> ClerkPaginatedResponse<BillingPaymentMethod> {
    try await js(
      OrganizationJSCall.getPaymentMethods(
        ClerkSnapshots.GetPaymentMethodsParams(initialPage: params?.initialPage, pageSize: params?.pageSize)
      ),
      as: ClerkPaginatedResponse<BillingPaymentMethod>.self
    )
  }
}

extension Organization {
  private func page(fromOffset offset: Int, pageSize: Int) -> Int {
    guard pageSize > 0 else { return 1 }
    return offset / pageSize + 1
  }

  @MainActor
  private func js<T: Decodable>(_ call: OrganizationJSCall, as _: T.Type) async throws -> T {
    try await Clerk.js(.organization(id: ClerkJSResourceID(id)), call, as: T.self)
  }

  @MainActor
  private func memberships(
    query: String?,
    role: [String]?,
    page: Int,
    pageSize: Int
  ) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    try await js(
      OrganizationJSCall.getMemberships(
        GetMembersParams(initialPage: page, pageSize: pageSize, role: role, query: query)
      ),
      as: ClerkPaginatedResponse<OrganizationMembership>.self
    )
  }

  @MainActor
  private func invitations(
    page: Int,
    pageSize: Int,
    status: [String]
  ) async throws -> ClerkPaginatedResponse<OrganizationInvitation> {
    try await js(
      OrganizationJSCall.getInvitations(
        GetInvitationsParams(
          initialPage: page,
          pageSize: pageSize,
          status: status.isEmpty ? nil : status.map(invitationStatus(from:))
        )
      ),
      as: ClerkPaginatedResponse<OrganizationInvitation>.self
    )
  }

  @MainActor
  private func domains(
    page: Int,
    pageSize: Int,
    enrollmentMode: String?
  ) async throws -> ClerkPaginatedResponse<OrganizationDomain> {
    try await js(
      OrganizationJSCall.getDomains(
        GetDomainsParams(
          initialPage: page,
          pageSize: pageSize,
          enrollmentMode: enrollmentMode.map(domainEnrollmentMode(from:))
        )
      ),
      as: ClerkPaginatedResponse<OrganizationDomain>.self
    )
  }

  @MainActor
  private func membershipRequests(
    page: Int,
    pageSize: Int,
    status: String?
  ) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest> {
    try await js(
      OrganizationJSCall.getMembershipRequests(
        GetMembershipRequestParams(
          initialPage: page,
          pageSize: pageSize,
          status: status.map(membershipRequestStatus(from:))
        )
      ),
      as: ClerkPaginatedResponse<OrganizationMembershipRequest>.self
    )
  }

  private func invitationStatus(from raw: String) -> OrganizationInvitationStatus {
    switch raw {
    case "expired":
      .expired
    case "revoked":
      .revoked
    case "pending":
      .pending
    case "accepted":
      .accepted
    default:
      .unknown(raw)
    }
  }

  private func membershipRequestStatus(from raw: String) -> GetUserOrganizationInvitationsParamsStatus {
    switch raw {
    case "expired":
      .expired
    case "revoked":
      .revoked
    case "pending":
      .pending
    case "accepted":
      .accepted
    default:
      .unknown(raw)
    }
  }

  private func domainEnrollmentMode(from raw: String) -> GetDomainsParamsEnrollmentMode {
    switch raw {
    case "enterprise_sso":
      .enterpriseSso
    case "manual_invitation":
      .manualInvitation
    case "automatic_invitation":
      .automaticInvitation
    case "automatic_suggestion":
      .automaticSuggestion
    default:
      .unknown(raw)
    }
  }
}
