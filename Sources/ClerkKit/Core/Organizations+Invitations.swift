//
//  Organizations+Invitations.swift
//  Clerk
//

import Foundation

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
