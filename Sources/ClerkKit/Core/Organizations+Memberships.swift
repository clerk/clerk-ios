//
//  Organizations+Memberships.swift
//  Clerk
//

import Foundation

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
