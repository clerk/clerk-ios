//
//  Organizations+Requests.swift
//  Clerk
//

import Foundation

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
