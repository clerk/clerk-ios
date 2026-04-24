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
package final class MockOrganizationService: OrganizationServiceProtocol {
  /// Custom handler for the `createOrganization(name:slug:)` method.
  package nonisolated(unsafe) var createOrganizationHandler: ((String?, String, String?) async throws -> Organization)?

  /// Custom handler for the `updateOrganization(organizationId:name:slug:)` method.
  package nonisolated(unsafe) var updateOrganizationHandler: ((String?, String, String, String?) async throws -> Organization)?

  /// Custom handler for the `destroyOrganization(organizationId:)` method.
  package nonisolated(unsafe) var destroyOrganizationHandler: ((String?, String) async throws -> DeletedObject)?

  /// Custom handler for the `setOrganizationLogo(organizationId:imageData:)` method.
  package nonisolated(unsafe) var setOrganizationLogoHandler: ((String?, String, Data) async throws -> Organization)?

  /// Custom handler for the `getOrganizationRoles(organizationId:offset:pageSize:)` method.
  package nonisolated(unsafe) var getOrganizationRolesHandler: ((String?, String, Int, Int) async throws -> ClerkPaginatedResponse<RoleResource>)?

  /// Custom handler for the `getOrganizationMemberships(organizationId:query:role:offset:pageSize:)` method.
  package nonisolated(unsafe) var getOrganizationMembershipsHandler: ((String?, String, String?, [String]?, Int, Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>)?

  /// Custom handler for the `addOrganizationMember(organizationId:userId:role:)` method.
  package nonisolated(unsafe) var addOrganizationMemberHandler: ((String?, String, String, String) async throws -> OrganizationMembership)?

  /// Custom handler for the `updateOrganizationMember(organizationId:userId:role:)` method.
  package nonisolated(unsafe) var updateOrganizationMemberHandler: ((String?, String, String, String) async throws -> OrganizationMembership)?

  /// Custom handler for the `removeOrganizationMember(organizationId:userId:)` method.
  package nonisolated(unsafe) var removeOrganizationMemberHandler: ((String?, String, String) async throws -> OrganizationMembership)?

  /// Custom handler for the `getOrganizationInvitations(organizationId:offset:pageSize:status:)` method.
  package nonisolated(unsafe) var getOrganizationInvitationsHandler: ((String?, String, Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationInvitation>)?

  /// Custom handler for the `inviteOrganizationMember(organizationId:emailAddress:role:)` method.
  package nonisolated(unsafe) var inviteOrganizationMemberHandler: ((String?, String, String, String) async throws -> OrganizationInvitation)?

  /// Custom handler for the `createOrganizationDomain(organizationId:domainName:)` method.
  package nonisolated(unsafe) var createOrganizationDomainHandler: ((String?, String, String) async throws -> OrganizationDomain)?

  /// Custom handler for the `getOrganizationDomains(organizationId:offset:pageSize:enrollmentMode:)` method.
  package nonisolated(unsafe) var getOrganizationDomainsHandler: ((String?, String, Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationDomain>)?

  /// Custom handler for the `getOrganizationDomain(organizationId:domainId:)` method.
  package nonisolated(unsafe) var getOrganizationDomainHandler: ((String?, String, String) async throws -> OrganizationDomain)?

  /// Custom handler for the `getOrganizationMembershipRequests(organizationId:offset:pageSize:status:)` method.
  package nonisolated(unsafe) var getOrganizationMembershipRequestsHandler: ((String?, String, Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest>)?

  /// Custom handler for the `deleteOrganizationDomain(organizationId:domainId:)` method.
  package nonisolated(unsafe) var deleteOrganizationDomainHandler: ((String, String) async throws -> DeletedObject)?

  /// Custom handler for the `prepareOrganizationDomainAffiliationVerification(organizationId:domainId:affiliationEmailAddress:)` method.
  package nonisolated(unsafe) var prepareOrganizationDomainAffiliationVerificationHandler: ((String, String, String) async throws -> OrganizationDomain)? // swiftlint:disable:this identifier_name

  /// Custom handler for the `attemptOrganizationDomainAffiliationVerification(organizationId:domainId:code:)` method.
  package nonisolated(unsafe) var attemptOrganizationDomainAffiliationVerificationHandler: ((String, String, String) async throws -> OrganizationDomain)? // swiftlint:disable:this identifier_name

  /// Custom handler for the `revokeOrganizationInvitation(organizationId:invitationId:)` method.
  package nonisolated(unsafe) var revokeOrganizationInvitationHandler: ((String, String) async throws -> OrganizationInvitation)?

  /// Custom handler for the `destroyOrganizationMembership(organizationId:userId:)` method.
  package nonisolated(unsafe) var destroyOrganizationMembershipHandler: ((String, String) async throws -> OrganizationMembership)?

  /// Custom handler for the `acceptUserOrganizationInvitation(invitationId:)` method.
  package nonisolated(unsafe) var acceptUserOrganizationInvitationHandler: ((String?, String) async throws -> UserOrganizationInvitation)?

  /// Custom handler for the `acceptOrganizationSuggestion(suggestionId:)` method.
  package nonisolated(unsafe) var acceptOrganizationSuggestionHandler: ((String?, String) async throws -> OrganizationSuggestion)?

  /// Custom handler for the `acceptOrganizationMembershipRequest(organizationId:requestId:)` method.
  package nonisolated(unsafe) var acceptOrganizationMembershipRequestHandler: ((String, String) async throws -> OrganizationMembershipRequest)? // swiftlint:disable:this identifier_name

  /// Custom handler for the `rejectOrganizationMembershipRequest(organizationId:requestId:)` method.
  package nonisolated(unsafe) var rejectOrganizationMembershipRequestHandler: ((String, String) async throws -> OrganizationMembershipRequest)? // swiftlint:disable:this identifier_name

  package init(
    createOrganization: ((String?, String, String?) async throws -> Organization)? = nil,
    updateOrganization: ((String?, String, String, String?) async throws -> Organization)? = nil,
    destroyOrganization: ((String?, String) async throws -> DeletedObject)? = nil,
    setOrganizationLogo: ((String?, String, Data) async throws -> Organization)? = nil,
    getOrganizationRoles: ((String?, String, Int, Int) async throws -> ClerkPaginatedResponse<RoleResource>)? = nil,
    getOrganizationMemberships: ((String?, String, String?, [String]?, Int, Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>)? = nil,
    addOrganizationMember: ((String?, String, String, String) async throws -> OrganizationMembership)? = nil,
    updateOrganizationMember: ((String?, String, String, String) async throws -> OrganizationMembership)? = nil,
    removeOrganizationMember: ((String?, String, String) async throws -> OrganizationMembership)? = nil,
    getOrganizationInvitations: ((String?, String, Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationInvitation>)? = nil,
    inviteOrganizationMember: ((String?, String, String, String) async throws -> OrganizationInvitation)? = nil,
    createOrganizationDomain: ((String?, String, String) async throws -> OrganizationDomain)? = nil,
    getOrganizationDomains: ((String?, String, Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationDomain>)? = nil,
    getOrganizationDomain: ((String?, String, String) async throws -> OrganizationDomain)? = nil,
    getOrganizationMembershipRequests: ((String?, String, Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest>)? = nil,
    deleteOrganizationDomain: ((String, String) async throws -> DeletedObject)? = nil,
    // swiftlint:disable:next identifier_name
    prepareOrganizationDomainAffiliationVerification: ((String, String, String) async throws -> OrganizationDomain)? = nil,
    // swiftlint:disable:next identifier_name
    attemptOrganizationDomainAffiliationVerification: ((String, String, String) async throws -> OrganizationDomain)? = nil,
    revokeOrganizationInvitation: ((String, String) async throws -> OrganizationInvitation)? = nil,
    destroyOrganizationMembership: ((String, String) async throws -> OrganizationMembership)? = nil,
    acceptUserOrganizationInvitation: ((String?, String) async throws -> UserOrganizationInvitation)? = nil,
    acceptOrganizationSuggestion: ((String?, String) async throws -> OrganizationSuggestion)? = nil,
    acceptOrganizationMembershipRequest: ((String, String) async throws -> OrganizationMembershipRequest)? = nil,
    rejectOrganizationMembershipRequest: ((String, String) async throws -> OrganizationMembershipRequest)? = nil
  ) {
    createOrganizationHandler = createOrganization
    updateOrganizationHandler = updateOrganization
    destroyOrganizationHandler = destroyOrganization
    setOrganizationLogoHandler = setOrganizationLogo
    getOrganizationRolesHandler = getOrganizationRoles
    getOrganizationMembershipsHandler = getOrganizationMemberships
    addOrganizationMemberHandler = addOrganizationMember
    updateOrganizationMemberHandler = updateOrganizationMember
    removeOrganizationMemberHandler = removeOrganizationMember
    getOrganizationInvitationsHandler = getOrganizationInvitations
    inviteOrganizationMemberHandler = inviteOrganizationMember
    createOrganizationDomainHandler = createOrganizationDomain
    getOrganizationDomainsHandler = getOrganizationDomains
    getOrganizationDomainHandler = getOrganizationDomain
    getOrganizationMembershipRequestsHandler = getOrganizationMembershipRequests
    deleteOrganizationDomainHandler = deleteOrganizationDomain
    prepareOrganizationDomainAffiliationVerificationHandler = prepareOrganizationDomainAffiliationVerification
    attemptOrganizationDomainAffiliationVerificationHandler = attemptOrganizationDomainAffiliationVerification
    revokeOrganizationInvitationHandler = revokeOrganizationInvitation
    destroyOrganizationMembershipHandler = destroyOrganizationMembership
    acceptUserOrganizationInvitationHandler = acceptUserOrganizationInvitation
    acceptOrganizationSuggestionHandler = acceptOrganizationSuggestion
    acceptOrganizationMembershipRequestHandler = acceptOrganizationMembershipRequest
    rejectOrganizationMembershipRequestHandler = rejectOrganizationMembershipRequest
  }

  @MainActor
  package func createOrganization(name: String, slug: String?, sessionId: String?) async throws -> Organization {
    if let handler = createOrganizationHandler {
      return try await handler(sessionId, name, slug)
    }
    return .mock
  }

  @MainActor
  package func updateOrganization(organizationId: String, name: String, slug: String?, sessionId: String?) async throws -> Organization {
    if let handler = updateOrganizationHandler {
      return try await handler(sessionId, organizationId, name, slug)
    }
    return .mock
  }

  @MainActor
  package func destroyOrganization(organizationId: String, sessionId: String?) async throws -> DeletedObject {
    if let handler = destroyOrganizationHandler {
      return try await handler(sessionId, organizationId)
    }
    return .mock
  }

  @MainActor
  package func setOrganizationLogo(organizationId: String, imageData: Data, sessionId: String?) async throws -> Organization {
    if let handler = setOrganizationLogoHandler {
      return try await handler(sessionId, organizationId, imageData)
    }
    return .mock
  }

  @MainActor
  package func getOrganizationRoles(organizationId: String, offset: Int, pageSize: Int, sessionId: String?) async throws -> ClerkPaginatedResponse<RoleResource> {
    if let handler = getOrganizationRolesHandler {
      return try await handler(sessionId, organizationId, offset, pageSize)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func getOrganizationMemberships(organizationId: String, query: String?, role: [String]?, offset: Int, pageSize: Int, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    if let handler = getOrganizationMembershipsHandler {
      return try await handler(sessionId, organizationId, query, role, offset, pageSize)
    }
    return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
  }

  @MainActor
  package func addOrganizationMember(organizationId: String, userId: String, role: String, sessionId: String?) async throws -> OrganizationMembership {
    if let handler = addOrganizationMemberHandler {
      return try await handler(sessionId, organizationId, userId, role)
    }
    return .mockWithUserData
  }

  @MainActor
  package func updateOrganizationMember(organizationId: String, userId: String, role: String, sessionId: String?) async throws -> OrganizationMembership {
    if let handler = updateOrganizationMemberHandler {
      return try await handler(sessionId, organizationId, userId, role)
    }
    return .mockWithUserData
  }

  @MainActor
  package func removeOrganizationMember(organizationId: String, userId: String, sessionId: String?) async throws -> OrganizationMembership {
    if let handler = removeOrganizationMemberHandler {
      return try await handler(sessionId, organizationId, userId)
    }
    return .mockWithUserData
  }

  @MainActor
  package func getOrganizationInvitations(organizationId: String, offset: Int, pageSize: Int, status: String?, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationInvitation> {
    if let handler = getOrganizationInvitationsHandler {
      return try await handler(sessionId, organizationId, offset, pageSize, status)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func inviteOrganizationMember(organizationId: String, emailAddress: String, role: String, sessionId: String?) async throws -> OrganizationInvitation {
    if let handler = inviteOrganizationMemberHandler {
      return try await handler(sessionId, organizationId, emailAddress, role)
    }
    return .mock
  }

  @MainActor
  package func createOrganizationDomain(organizationId: String, domainName: String, sessionId: String?) async throws -> OrganizationDomain {
    if let handler = createOrganizationDomainHandler {
      return try await handler(sessionId, organizationId, domainName)
    }
    return .mock
  }

  @MainActor
  package func getOrganizationDomains(organizationId: String, offset: Int, pageSize: Int, enrollmentMode: String?, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationDomain> {
    if let handler = getOrganizationDomainsHandler {
      return try await handler(sessionId, organizationId, offset, pageSize, enrollmentMode)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func getOrganizationDomain(organizationId: String, domainId: String, sessionId: String?) async throws -> OrganizationDomain {
    if let handler = getOrganizationDomainHandler {
      return try await handler(sessionId, organizationId, domainId)
    }
    return .mock
  }

  @MainActor
  package func getOrganizationMembershipRequests(organizationId: String, offset: Int, pageSize: Int, status: String?, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest> {
    if let handler = getOrganizationMembershipRequestsHandler {
      return try await handler(sessionId, organizationId, offset, pageSize, status)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func deleteOrganizationDomain(organizationId: String, domainId: String) async throws -> DeletedObject {
    if let handler = deleteOrganizationDomainHandler {
      return try await handler(organizationId, domainId)
    }
    return .mock
  }

  @MainActor
  package func prepareOrganizationDomainAffiliationVerification(organizationId: String, domainId: String, affiliationEmailAddress: String) async throws -> OrganizationDomain {
    if let handler = prepareOrganizationDomainAffiliationVerificationHandler {
      return try await handler(organizationId, domainId, affiliationEmailAddress)
    }
    return .mock
  }

  @MainActor
  package func attemptOrganizationDomainAffiliationVerification(organizationId: String, domainId: String, code: String) async throws -> OrganizationDomain {
    if let handler = attemptOrganizationDomainAffiliationVerificationHandler {
      return try await handler(organizationId, domainId, code)
    }
    return .mock
  }

  @MainActor
  package func revokeOrganizationInvitation(organizationId: String, invitationId: String) async throws -> OrganizationInvitation {
    if let handler = revokeOrganizationInvitationHandler {
      return try await handler(organizationId, invitationId)
    }
    return .mock
  }

  @MainActor
  package func destroyOrganizationMembership(organizationId: String, userId: String) async throws -> OrganizationMembership {
    if let handler = destroyOrganizationMembershipHandler {
      return try await handler(organizationId, userId)
    }
    return .mockWithUserData
  }

  @MainActor
  package func acceptUserOrganizationInvitation(invitationId: String, sessionId: String?) async throws -> UserOrganizationInvitation {
    if let handler = acceptUserOrganizationInvitationHandler {
      return try await handler(sessionId, invitationId)
    }
    return .mock
  }

  @MainActor
  package func acceptOrganizationSuggestion(suggestionId: String, sessionId: String?) async throws -> OrganizationSuggestion {
    if let handler = acceptOrganizationSuggestionHandler {
      return try await handler(sessionId, suggestionId)
    }
    return .mock
  }

  @MainActor
  package func acceptOrganizationMembershipRequest(organizationId: String, requestId: String) async throws -> OrganizationMembershipRequest {
    if let handler = acceptOrganizationMembershipRequestHandler {
      return try await handler(organizationId, requestId)
    }
    return .mock
  }

  @MainActor
  package func rejectOrganizationMembershipRequest(organizationId: String, requestId: String) async throws -> OrganizationMembershipRequest {
    if let handler = rejectOrganizationMembershipRequestHandler {
      return try await handler(organizationId, requestId)
    }
    return .mock
  }
}
