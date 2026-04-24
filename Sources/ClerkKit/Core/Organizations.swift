//
//  Organizations.swift
//  Clerk
//

import Foundation

/// The main entry point for organization operations in the Clerk SDK.
///
/// Access this via `clerk.organizations` to create organizations and perform
/// organization-scoped operations.
@MainActor
public struct Organizations {
  let clerk: Clerk
  let organizationService: OrganizationServiceProtocol
}

// MARK: - Lifecycle

extension Organizations {
  /// Creates an organization and makes the current user its administrator.
  ///
  /// - Parameters:
  ///   - name: The organization name.
  ///   - slug: The optional organization slug.
  /// - Returns: The newly created ``Organization``.
  @discardableResult
  public func create(name: String, slug: String? = nil) async throws -> Organization {
    try await organizationService.createOrganization(name: name, slug: slug, sessionId: clerk.session?.id)
  }

  @discardableResult
  func update(_ organization: Organization, name: String, slug: String? = nil) async throws -> Organization {
    try await organizationService.updateOrganization(
      organizationId: organization.id,
      name: name,
      slug: slug,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func destroy(_ organization: Organization) async throws -> DeletedObject {
    try await organizationService.destroyOrganization(organizationId: organization.id, sessionId: clerk.session?.id)
  }

  @discardableResult
  func setLogo(for organization: Organization, imageData: Data) async throws -> Organization {
    try await organizationService.setOrganizationLogo(
      organizationId: organization.id,
      imageData: imageData,
      sessionId: clerk.session?.id
    )
  }
}

// MARK: - Roles

extension Organizations {
  func getRoles(
    for organization: Organization,
    page: Int = 1,
    pageSize: Int = 20
  ) async throws -> ClerkPaginatedResponse<RoleResource> {
    try await organizationService.getOrganizationRoles(
      organizationId: organization.id,
      initialPage: offset(forPage: page, pageSize: pageSize),
      pageSize: pageSize,
      sessionId: clerk.session?.id
    )
  }
}

// MARK: - Memberships

extension Organizations {
  func getMemberships(
    for organization: Organization,
    query: String? = nil,
    role: [String]? = nil,
    page: Int = 1,
    pageSize: Int = 20
  ) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    try await organizationService.getOrganizationMemberships(
      organizationId: organization.id,
      query: query,
      role: role,
      initialPage: offset(forPage: page, pageSize: pageSize),
      pageSize: pageSize,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func addMember(
    to organization: Organization,
    userId: String,
    role: String
  ) async throws -> OrganizationMembership {
    try await organizationService.addOrganizationMember(
      organizationId: organization.id,
      userId: userId,
      role: role,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func updateMember(
    in organization: Organization,
    userId: String,
    role: String
  ) async throws -> OrganizationMembership {
    try await organizationService.updateOrganizationMember(
      organizationId: organization.id,
      userId: userId,
      role: role,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func removeMember(
    from organization: Organization,
    userId: String
  ) async throws -> OrganizationMembership {
    try await organizationService.removeOrganizationMember(
      organizationId: organization.id,
      userId: userId,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func update(_ membership: OrganizationMembership, role: String) async throws -> OrganizationMembership {
    guard let userId = membership.publicUserData?.userId else {
      throw ClerkClientError(message: "Unable to update membership: missing userId")
    }

    return try await organizationService.updateOrganizationMember(
      organizationId: membership.organization.id,
      userId: userId,
      role: role,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func destroy(_ membership: OrganizationMembership) async throws -> OrganizationMembership {
    guard let userId = membership.publicUserData?.userId else {
      throw ClerkClientError(message: "Unable to delete membership: missing userId")
    }

    return try await organizationService.destroyOrganizationMembership(
      organizationId: membership.organization.id,
      userId: userId,
      sessionId: clerk.session?.id
    )
  }
}

// MARK: - Invitations

extension Organizations {
  func getInvitations(
    for organization: Organization,
    page: Int = 1,
    pageSize: Int = 20,
    status: String? = nil
  ) async throws -> ClerkPaginatedResponse<OrganizationInvitation> {
    try await organizationService.getOrganizationInvitations(
      organizationId: organization.id,
      initialPage: offset(forPage: page, pageSize: pageSize),
      pageSize: pageSize,
      status: status,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func inviteMember(
    to organization: Organization,
    emailAddress: String,
    role: String
  ) async throws -> OrganizationInvitation {
    try await organizationService.inviteOrganizationMember(
      organizationId: organization.id,
      emailAddress: emailAddress,
      role: role,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func revoke(_ invitation: OrganizationInvitation) async throws -> OrganizationInvitation {
    try await organizationService.revokeOrganizationInvitation(
      organizationId: invitation.organizationId,
      invitationId: invitation.id,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func accept(_ invitation: UserOrganizationInvitation) async throws -> UserOrganizationInvitation {
    try await organizationService.acceptUserOrganizationInvitation(
      invitationId: invitation.id,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func accept(_ suggestion: OrganizationSuggestion) async throws -> OrganizationSuggestion {
    try await organizationService.acceptOrganizationSuggestion(
      suggestionId: suggestion.id,
      sessionId: clerk.session?.id
    )
  }
}

// MARK: - Domains

extension Organizations {
  @discardableResult
  func createDomain(
    for organization: Organization,
    domainName: String
  ) async throws -> OrganizationDomain {
    try await organizationService.createOrganizationDomain(
      organizationId: organization.id,
      domainName: domainName,
      sessionId: clerk.session?.id
    )
  }

  func getDomains(
    for organization: Organization,
    page: Int = 1,
    pageSize: Int = 20,
    enrollmentMode: String? = nil
  ) async throws -> ClerkPaginatedResponse<OrganizationDomain> {
    try await organizationService.getOrganizationDomains(
      organizationId: organization.id,
      initialPage: offset(forPage: page, pageSize: pageSize),
      pageSize: pageSize,
      enrollmentMode: enrollmentMode,
      sessionId: clerk.session?.id
    )
  }

  func getDomain(
    for organization: Organization,
    domainId: String
  ) async throws -> OrganizationDomain {
    try await organizationService.getOrganizationDomain(
      organizationId: organization.id,
      domainId: domainId,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func delete(_ domain: OrganizationDomain) async throws -> DeletedObject {
    try await organizationService.deleteOrganizationDomain(
      organizationId: domain.organizationId,
      domainId: domain.id,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func sendEmailCode(
    for domain: OrganizationDomain,
    affiliationEmailAddress: String
  ) async throws -> OrganizationDomain {
    try await organizationService.prepareOrganizationDomainAffiliationVerification(
      organizationId: domain.organizationId,
      domainId: domain.id,
      affiliationEmailAddress: affiliationEmailAddress,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func verifyCode(
    _ code: String,
    for domain: OrganizationDomain
  ) async throws -> OrganizationDomain {
    try await organizationService.attemptOrganizationDomainAffiliationVerification(
      organizationId: domain.organizationId,
      domainId: domain.id,
      code: code,
      sessionId: clerk.session?.id
    )
  }
}

// MARK: - Membership Requests

extension Organizations {
  func getMembershipRequests(
    for organization: Organization,
    page: Int = 1,
    pageSize: Int = 20,
    status: String? = nil
  ) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest> {
    try await organizationService.getOrganizationMembershipRequests(
      organizationId: organization.id,
      initialPage: offset(forPage: page, pageSize: pageSize),
      pageSize: pageSize,
      status: status,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func accept(_ request: OrganizationMembershipRequest) async throws -> OrganizationMembershipRequest {
    try await organizationService.acceptOrganizationMembershipRequest(
      organizationId: request.organizationId,
      requestId: request.id,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func reject(_ request: OrganizationMembershipRequest) async throws -> OrganizationMembershipRequest {
    try await organizationService.rejectOrganizationMembershipRequest(
      organizationId: request.organizationId,
      requestId: request.id,
      sessionId: clerk.session?.id
    )
  }
}

// MARK: - Helpers

extension Organizations {
  func offset(forPage page: Int, pageSize: Int) -> Int {
    max(page - 1, 0) * pageSize
  }
}
