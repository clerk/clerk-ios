//
//  MockOrganizationService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Mock implementation of `OrganizationServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of service methods through handler closures.
/// All methods return default mock values if handlers are not provided.
public final class MockOrganizationService: OrganizationServiceProtocol {
  /// Custom handler for the `updateOrganization(organizationId:name:slug:)` method.
  public nonisolated(unsafe) var updateOrganizationHandler: ((String, String, String?) async throws -> Organization)?

  /// Custom handler for the `destroyOrganization(organizationId:)` method.
  public nonisolated(unsafe) var destroyOrganizationHandler: ((String) async throws -> DeletedObject)?

  /// Custom handler for the `setOrganizationLogo(organizationId:imageData:)` method.
  public nonisolated(unsafe) var setOrganizationLogoHandler: ((String, Data) async throws -> Organization)?

  /// Custom handler for the `getOrganizationRoles(organizationId:initialPage:pageSize:)` method.
  public nonisolated(unsafe) var getOrganizationRolesHandler: ((String, Int, Int) async throws -> ClerkPaginatedResponse<RoleResource>)?

  /// Custom handler for the `getOrganizationMemberships(organizationId:query:role:initialPage:pageSize:)` method.
  public nonisolated(unsafe) var getOrganizationMembershipsHandler: ((String, String?, [String]?, Int, Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>)?

  /// Custom handler for the `addOrganizationMember(organizationId:userId:role:)` method.
  public nonisolated(unsafe) var addOrganizationMemberHandler: ((String, String, String) async throws -> OrganizationMembership)?

  /// Custom handler for the `updateOrganizationMember(organizationId:userId:role:)` method.
  public nonisolated(unsafe) var updateOrganizationMemberHandler: ((String, String, String) async throws -> OrganizationMembership)?

  /// Custom handler for the `removeOrganizationMember(organizationId:userId:)` method.
  public nonisolated(unsafe) var removeOrganizationMemberHandler: ((String, String) async throws -> OrganizationMembership)?

  /// Custom handler for the `getOrganizationInvitations(organizationId:initialPage:pageSize:status:)` method.
  public nonisolated(unsafe) var getOrganizationInvitationsHandler: ((String, Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationInvitation>)?

  /// Custom handler for the `inviteOrganizationMember(organizationId:emailAddress:role:)` method.
  public nonisolated(unsafe) var inviteOrganizationMemberHandler: ((String, String, String) async throws -> OrganizationInvitation)?

  /// Custom handler for the `createOrganizationDomain(organizationId:domainName:)` method.
  public nonisolated(unsafe) var createOrganizationDomainHandler: ((String, String) async throws -> OrganizationDomain)?

  /// Custom handler for the `getOrganizationDomains(organizationId:initialPage:pageSize:enrollmentMode:)` method.
  public nonisolated(unsafe) var getOrganizationDomainsHandler: ((String, Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationDomain>)?

  /// Custom handler for the `getOrganizationDomain(organizationId:domainId:)` method.
  public nonisolated(unsafe) var getOrganizationDomainHandler: ((String, String) async throws -> OrganizationDomain)?

  /// Custom handler for the `getOrganizationMembershipRequests(organizationId:initialPage:pageSize:status:)` method.
  public nonisolated(unsafe) var getOrganizationMembershipRequestsHandler: ((String, Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest>)?

  /// Custom handler for the `deleteOrganizationDomain(organizationId:domainId:)` method.
  public nonisolated(unsafe) var deleteOrganizationDomainHandler: ((String, String) async throws -> DeletedObject)?

  /// Custom handler for the `prepareOrganizationDomainAffiliationVerification(organizationId:domainId:affiliationEmailAddress:)` method.
  public nonisolated(unsafe) var prepareOrganizationDomainAffiliationVerificationHandler: ((String, String, String) async throws -> OrganizationDomain)?

  /// Custom handler for the `attemptOrganizationDomainAffiliationVerification(organizationId:domainId:code:)` method.
  public nonisolated(unsafe) var attemptOrganizationDomainAffiliationVerificationHandler: ((String, String, String) async throws -> OrganizationDomain)?

  /// Custom handler for the `revokeOrganizationInvitation(organizationId:invitationId:)` method.
  public nonisolated(unsafe) var revokeOrganizationInvitationHandler: ((String, String) async throws -> OrganizationInvitation)?

  /// Custom handler for the `destroyOrganizationMembership(organizationId:userId:)` method.
  public nonisolated(unsafe) var destroyOrganizationMembershipHandler: ((String, String) async throws -> OrganizationMembership)?

  /// Custom handler for the `acceptUserOrganizationInvitation(invitationId:)` method.
  public nonisolated(unsafe) var acceptUserOrganizationInvitationHandler: ((String) async throws -> UserOrganizationInvitation)?

  /// Custom handler for the `acceptOrganizationSuggestion(suggestionId:)` method.
  public nonisolated(unsafe) var acceptOrganizationSuggestionHandler: ((String) async throws -> OrganizationSuggestion)?

  /// Custom handler for the `acceptOrganizationMembershipRequest(organizationId:requestId:)` method.
  public nonisolated(unsafe) var acceptOrganizationMembershipRequestHandler: ((String, String) async throws -> OrganizationMembershipRequest)?

  /// Custom handler for the `rejectOrganizationMembershipRequest(organizationId:requestId:)` method.
  public nonisolated(unsafe) var rejectOrganizationMembershipRequestHandler: ((String, String) async throws -> OrganizationMembershipRequest)?

  public init(
    updateOrganization: ((String, String, String?) async throws -> Organization)? = nil,
    destroyOrganization: ((String) async throws -> DeletedObject)? = nil,
    setOrganizationLogo: ((String, Data) async throws -> Organization)? = nil,
    getOrganizationRoles: ((String, Int, Int) async throws -> ClerkPaginatedResponse<RoleResource>)? = nil,
    getOrganizationMemberships: ((String, String?, [String]?, Int, Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>)? = nil,
    addOrganizationMember: ((String, String, String) async throws -> OrganizationMembership)? = nil,
    updateOrganizationMember: ((String, String, String) async throws -> OrganizationMembership)? = nil,
    removeOrganizationMember: ((String, String) async throws -> OrganizationMembership)? = nil,
    getOrganizationInvitations: ((String, Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationInvitation>)? = nil,
    inviteOrganizationMember: ((String, String, String) async throws -> OrganizationInvitation)? = nil,
    createOrganizationDomain: ((String, String) async throws -> OrganizationDomain)? = nil,
    getOrganizationDomains: ((String, Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationDomain>)? = nil,
    getOrganizationDomain: ((String, String) async throws -> OrganizationDomain)? = nil,
    getOrganizationMembershipRequests: ((String, Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest>)? = nil,
    deleteOrganizationDomain: ((String, String) async throws -> DeletedObject)? = nil,
    prepareOrganizationDomainAffiliationVerification: ((String, String, String) async throws -> OrganizationDomain)? = nil,
    attemptOrganizationDomainAffiliationVerification: ((String, String, String) async throws -> OrganizationDomain)? = nil,
    revokeOrganizationInvitation: ((String, String) async throws -> OrganizationInvitation)? = nil,
    destroyOrganizationMembership: ((String, String) async throws -> OrganizationMembership)? = nil,
    acceptUserOrganizationInvitation: ((String) async throws -> UserOrganizationInvitation)? = nil,
    acceptOrganizationSuggestion: ((String) async throws -> OrganizationSuggestion)? = nil,
    acceptOrganizationMembershipRequest: ((String, String) async throws -> OrganizationMembershipRequest)? = nil,
    rejectOrganizationMembershipRequest: ((String, String) async throws -> OrganizationMembershipRequest)? = nil
  ) {
    self.updateOrganizationHandler = updateOrganization
    self.destroyOrganizationHandler = destroyOrganization
    self.setOrganizationLogoHandler = setOrganizationLogo
    self.getOrganizationRolesHandler = getOrganizationRoles
    self.getOrganizationMembershipsHandler = getOrganizationMemberships
    self.addOrganizationMemberHandler = addOrganizationMember
    self.updateOrganizationMemberHandler = updateOrganizationMember
    self.removeOrganizationMemberHandler = removeOrganizationMember
    self.getOrganizationInvitationsHandler = getOrganizationInvitations
    self.inviteOrganizationMemberHandler = inviteOrganizationMember
    self.createOrganizationDomainHandler = createOrganizationDomain
    self.getOrganizationDomainsHandler = getOrganizationDomains
    self.getOrganizationDomainHandler = getOrganizationDomain
    self.getOrganizationMembershipRequestsHandler = getOrganizationMembershipRequests
    self.deleteOrganizationDomainHandler = deleteOrganizationDomain
    self.prepareOrganizationDomainAffiliationVerificationHandler = prepareOrganizationDomainAffiliationVerification
    self.attemptOrganizationDomainAffiliationVerificationHandler = attemptOrganizationDomainAffiliationVerification
    self.revokeOrganizationInvitationHandler = revokeOrganizationInvitation
    self.destroyOrganizationMembershipHandler = destroyOrganizationMembership
    self.acceptUserOrganizationInvitationHandler = acceptUserOrganizationInvitation
    self.acceptOrganizationSuggestionHandler = acceptOrganizationSuggestion
    self.acceptOrganizationMembershipRequestHandler = acceptOrganizationMembershipRequest
    self.rejectOrganizationMembershipRequestHandler = rejectOrganizationMembershipRequest
  }

  @MainActor
  public func updateOrganization(organizationId: String, name: String, slug: String?) async throws -> Organization {
    if let handler = updateOrganizationHandler {
      return try await handler(organizationId, name, slug)
    }
    return .mock
  }

  @MainActor
  public func destroyOrganization(organizationId: String) async throws -> DeletedObject {
    if let handler = destroyOrganizationHandler {
      return try await handler(organizationId)
    }
    return .mock
  }

  @MainActor
  public func setOrganizationLogo(organizationId: String, imageData: Data) async throws -> Organization {
    if let handler = setOrganizationLogoHandler {
      return try await handler(organizationId, imageData)
    }
    return .mock
  }

  @MainActor
  public func getOrganizationRoles(organizationId: String, initialPage: Int, pageSize: Int) async throws -> ClerkPaginatedResponse<RoleResource> {
    if let handler = getOrganizationRolesHandler {
      return try await handler(organizationId, initialPage, pageSize)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  public func getOrganizationMemberships(organizationId: String, query: String?, role: [String]?, initialPage: Int, pageSize: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    if let handler = getOrganizationMembershipsHandler {
      return try await handler(organizationId, query, role, initialPage, pageSize)
    }
    return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
  }

  @MainActor
  public func addOrganizationMember(organizationId: String, userId: String, role: String) async throws -> OrganizationMembership {
    if let handler = addOrganizationMemberHandler {
      return try await handler(organizationId, userId, role)
    }
    return .mockWithUserData
  }

  @MainActor
  public func updateOrganizationMember(organizationId: String, userId: String, role: String) async throws -> OrganizationMembership {
    if let handler = updateOrganizationMemberHandler {
      return try await handler(organizationId, userId, role)
    }
    return .mockWithUserData
  }

  @MainActor
  public func removeOrganizationMember(organizationId: String, userId: String) async throws -> OrganizationMembership {
    if let handler = removeOrganizationMemberHandler {
      return try await handler(organizationId, userId)
    }
    return .mockWithUserData
  }

  @MainActor
  public func getOrganizationInvitations(organizationId: String, initialPage: Int, pageSize: Int, status: String?) async throws -> ClerkPaginatedResponse<OrganizationInvitation> {
    if let handler = getOrganizationInvitationsHandler {
      return try await handler(organizationId, initialPage, pageSize, status)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  public func inviteOrganizationMember(organizationId: String, emailAddress: String, role: String) async throws -> OrganizationInvitation {
    if let handler = inviteOrganizationMemberHandler {
      return try await handler(organizationId, emailAddress, role)
    }
    return .mock
  }

  @MainActor
  public func createOrganizationDomain(organizationId: String, domainName: String) async throws -> OrganizationDomain {
    if let handler = createOrganizationDomainHandler {
      return try await handler(organizationId, domainName)
    }
    return .mock
  }

  @MainActor
  public func getOrganizationDomains(organizationId: String, initialPage: Int, pageSize: Int, enrollmentMode: String?) async throws -> ClerkPaginatedResponse<OrganizationDomain> {
    if let handler = getOrganizationDomainsHandler {
      return try await handler(organizationId, initialPage, pageSize, enrollmentMode)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  public func getOrganizationDomain(organizationId: String, domainId: String) async throws -> OrganizationDomain {
    if let handler = getOrganizationDomainHandler {
      return try await handler(organizationId, domainId)
    }
    return .mock
  }

  @MainActor
  public func getOrganizationMembershipRequests(organizationId: String, initialPage: Int, pageSize: Int, status: String?) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest> {
    if let handler = getOrganizationMembershipRequestsHandler {
      return try await handler(organizationId, initialPage, pageSize, status)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  public func deleteOrganizationDomain(organizationId: String, domainId: String) async throws -> DeletedObject {
    if let handler = deleteOrganizationDomainHandler {
      return try await handler(organizationId, domainId)
    }
    return .mock
  }

  @MainActor
  public func prepareOrganizationDomainAffiliationVerification(organizationId: String, domainId: String, affiliationEmailAddress: String) async throws -> OrganizationDomain {
    if let handler = prepareOrganizationDomainAffiliationVerificationHandler {
      return try await handler(organizationId, domainId, affiliationEmailAddress)
    }
    return .mock
  }

  @MainActor
  public func attemptOrganizationDomainAffiliationVerification(organizationId: String, domainId: String, code: String) async throws -> OrganizationDomain {
    if let handler = attemptOrganizationDomainAffiliationVerificationHandler {
      return try await handler(organizationId, domainId, code)
    }
    return .mock
  }

  @MainActor
  public func revokeOrganizationInvitation(organizationId: String, invitationId: String) async throws -> OrganizationInvitation {
    if let handler = revokeOrganizationInvitationHandler {
      return try await handler(organizationId, invitationId)
    }
    return .mock
  }

  @MainActor
  public func destroyOrganizationMembership(organizationId: String, userId: String) async throws -> OrganizationMembership {
    if let handler = destroyOrganizationMembershipHandler {
      return try await handler(organizationId, userId)
    }
    return .mockWithUserData
  }

  @MainActor
  public func acceptUserOrganizationInvitation(invitationId: String) async throws -> UserOrganizationInvitation {
    if let handler = acceptUserOrganizationInvitationHandler {
      return try await handler(invitationId)
    }
    return .mock
  }

  @MainActor
  public func acceptOrganizationSuggestion(suggestionId: String) async throws -> OrganizationSuggestion {
    if let handler = acceptOrganizationSuggestionHandler {
      return try await handler(suggestionId)
    }
    return .mock
  }

  @MainActor
  public func acceptOrganizationMembershipRequest(organizationId: String, requestId: String) async throws -> OrganizationMembershipRequest {
    if let handler = acceptOrganizationMembershipRequestHandler {
      return try await handler(organizationId, requestId)
    }
    return .mock
  }

  @MainActor
  public func rejectOrganizationMembershipRequest(organizationId: String, requestId: String) async throws -> OrganizationMembershipRequest {
    if let handler = rejectOrganizationMembershipRequestHandler {
      return try await handler(organizationId, requestId)
    }
    return .mock
  }
}
