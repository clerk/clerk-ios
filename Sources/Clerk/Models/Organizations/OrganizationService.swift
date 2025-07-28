//
//  OrganizationService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation

extension Container {
  
  var organizationService: Factory<OrganizationService> {
    self { @MainActor in OrganizationService() }
  }
  
}

@MainActor
struct OrganizationService {
  
  // MARK: - Organization Methods
  
  var updateOrganization: (_ organizationId: String, _ name: String, _ slug: String?) async throws -> Organization = { organizationId, name, slug in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)")
      .method(.patch)
      .addClerkSessionId()
      .body(formEncode: [
        "name": name,
        "slug": slug,
      ])
      .data(type: ClientResponse<Organization>.self)
      .async()
      .response
  }
  
  var destroyOrganization: (_ organizationId: String) async throws -> DeletedObject = { organizationId in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)")
      .method(.delete)
      .addClerkSessionId()
      .data(type: ClientResponse<DeletedObject>.self)
      .async()
      .response
  }
  
  var setOrganizationLogo: (_ organizationId: String, _ imageData: Data) async throws -> Organization = { organizationId, imageData in
    let boundary = UUID().uuidString
    var data = Data()
    data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    data.append(imageData)
    data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

    return try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/logo")
      .body(data: data)
      .method(.put)
      .addClerkSessionId()
      .with { request in
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
      }
      .data(type: ClientResponse<Organization>.self)
      .async()
      .response
  }
  
  var getOrganizationRoles: (_ organizationId: String, _ initialPage: Int, _ pageSize: Int) async throws -> ClerkPaginatedResponse<RoleResource> = { organizationId, initialPage, pageSize in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/roles")
      .addClerkSessionId()
      .add(queryItems: [
        .init(name: "offset", value: String(initialPage)),
        .init(name: "limit", value: String(pageSize)),
      ])
      .data(type: ClientResponse<ClerkPaginatedResponse<RoleResource>>.self)
      .async()
      .response
  }
  
  var getOrganizationMemberships: (_ organizationId: String, _ query: String?, _ role: [String]?, _ initialPage: Int, _ pageSize: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership> = { organizationId, query, role, initialPage, pageSize in
    var queryItems = [
      URLQueryItem(name: "query", value: query),
      .init(name: "offset", value: String(initialPage)),
      .init(name: "limit", value: String(pageSize)),
      .init(name: "paginated", value: String(true)),
    ]

    queryItems += role?.map { URLQueryItem(name: "role[]", value: $0) } ?? []

    return try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/memberships")
      .addClerkSessionId()
      .add(queryItems: queryItems.filter({ $0.value != nil }))
      .data(type: ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>.self)
      .async()
      .response
  }
  
  var addOrganizationMember: (_ organizationId: String, _ userId: String, _ role: String) async throws -> OrganizationMembership = { organizationId, userId, role in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/memberships")
      .method(.post)
      .addClerkSessionId()
      .body(formEncode: [
        "user_id": userId,
        "role": role,
      ])
      .data(type: ClientResponse<OrganizationMembership>.self)
      .async()
      .response
  }
  
  var updateOrganizationMember: (_ organizationId: String, _ userId: String, _ role: String) async throws -> OrganizationMembership = { organizationId, userId, role in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/memberships/\(userId)")
      .method(.patch)
      .addClerkSessionId()
      .body(formEncode: [
        "role": role
      ])
      .data(type: ClientResponse<OrganizationMembership>.self)
      .async()
      .response
  }
  
  var removeOrganizationMember: (_ organizationId: String, _ userId: String) async throws -> OrganizationMembership = { organizationId, userId in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/memberships/\(userId)")
      .method(.delete)
      .addClerkSessionId()
      .data(type: ClientResponse<OrganizationMembership>.self)
      .async()
      .response
  }
  
  var getOrganizationInvitations: (_ organizationId: String, _ initialPage: Int, _ pageSize: Int, _ status: String?) async throws -> ClerkPaginatedResponse<OrganizationInvitation> = { organizationId, initialPage, pageSize, status in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/invitations")
      .addClerkSessionId()
      .add(queryItems: [
        .init(name: "offset", value: String(initialPage)),
        .init(name: "limit", value: String(pageSize)),
        .init(name: "status", value: status),
        .init(name: "paginated", value: String(true)),
      ].filter({ $0.value != nil }))
      .data(type: ClientResponse<ClerkPaginatedResponse<OrganizationInvitation>>.self)
      .async()
      .response
  }
  
  var inviteOrganizationMember: (_ organizationId: String, _ emailAddress: String, _ role: String) async throws -> OrganizationInvitation = { organizationId, emailAddress, role in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/invitations")
      .method(.post)
      .addClerkSessionId()
      .body(formEncode: [
        "email_address": emailAddress,
        "role": role,
      ])
      .data(type: ClientResponse<OrganizationInvitation>.self)
      .async()
      .response
  }
  
  var createOrganizationDomain: (_ organizationId: String, _ domainName: String) async throws -> OrganizationDomain = { organizationId, domainName in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/domains")
      .method(.post)
      .addClerkSessionId()
      .body(formEncode: [
        "name": domainName,
      ])
      .data(type: ClientResponse<OrganizationDomain>.self)
      .async()
      .response
  }
  
  var getOrganizationDomains: (_ organizationId: String, _ initialPage: Int, _ pageSize: Int, _ enrollmentMode: String?) async throws -> ClerkPaginatedResponse<OrganizationDomain> = { organizationId, initialPage, pageSize, enrollmentMode in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/domains")
      .addClerkSessionId()
      .add(queryItems: [
        .init(name: "offset", value: String(initialPage)),
        .init(name: "limit", value: String(pageSize)),
        .init(name: "enrollment_mode", value: enrollmentMode),
      ].filter({ $0.value != nil }))
      .data(type: ClientResponse<ClerkPaginatedResponse<OrganizationDomain>>.self)
      .async()
      .response
  }
  
  var getOrganizationDomain: (_ organizationId: String, _ domainId: String) async throws -> OrganizationDomain = { organizationId, domainId in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/domains/\(domainId)")
      .addClerkSessionId()
      .data(type: ClientResponse<OrganizationDomain>.self)
      .async()
      .response
  }
  
  var getOrganizationMembershipRequests: (_ organizationId: String, _ initialPage: Int, _ pageSize: Int, _ status: String?) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest> = { organizationId, initialPage, pageSize, status in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/membership_requests")
      .addClerkSessionId()
      .add(queryItems: [
        .init(name: "offset", value: String(initialPage)),
        .init(name: "limit", value: String(pageSize)),
        .init(name: "status", value: status),
      ].filter({ $0.value != nil }))
      .data(type: ClientResponse<ClerkPaginatedResponse<OrganizationMembershipRequest>>.self)
      .async()
      .response
  }
  
  // MARK: - Organization Domain Methods
  
  var deleteOrganizationDomain: (_ organizationId: String, _ domainId: String) async throws -> DeletedObject = { organizationId, domainId in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/domains/\(domainId)")
      .method(.delete)
      .data(type: ClientResponse<DeletedObject>.self)
      .async()
      .response
  }
  
  var prepareOrganizationDomainAffiliationVerification: (_ organizationId: String, _ domainId: String, _ affiliationEmailAddress: String) async throws -> OrganizationDomain = { organizationId, domainId, affiliationEmailAddress in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/domains/\(domainId)/prepare_affiliation_verification")
      .method(.post)
      .body(formEncode: ["affiliation_email_address": affiliationEmailAddress])
      .data(type: ClientResponse<OrganizationDomain>.self)
      .async()
      .response
  }
  
  var attemptOrganizationDomainAffiliationVerification: (_ organizationId: String, _ domainId: String, _ code: String) async throws -> OrganizationDomain = { organizationId, domainId, code in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/domains/\(domainId)/attempt_affiliation_verification")
      .method(.post)
      .body(formEncode: ["code": code])
      .data(type: ClientResponse<OrganizationDomain>.self)
      .async()
      .response
  }
  
  // MARK: - Organization Invitation Methods
  
  var revokeOrganizationInvitation: (_ organizationId: String, _ invitationId: String) async throws -> OrganizationInvitation = { organizationId, invitationId in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/invitations/\(invitationId)/revoke")
      .method(.post)
      .data(type: ClientResponse<OrganizationInvitation>.self)
      .async()
      .response
  }
  
  // MARK: - Organization Membership Methods
  
  var destroyOrganizationMembership: (_ organizationId: String, _ userId: String) async throws -> OrganizationMembership = { organizationId, userId in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/memberships/\(userId)")
      .method(.delete)
      .data(type: ClientResponse<OrganizationMembership>.self)
      .async()
      .response
  }
  
  var updateOrganizationMembership: (_ organizationId: String, _ userId: String, _ role: String) async throws -> OrganizationMembership = { organizationId, userId, role in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/memberships/\(userId)")
      .method(.patch)
      .body(formEncode: ["role": role])
      .data(type: ClientResponse<OrganizationMembership>.self)
      .async()
      .response
  }
  
  // MARK: - User Organization Invitation Methods
  
  var acceptUserOrganizationInvitation: (_ invitationId: String) async throws -> UserOrganizationInvitation = { invitationId in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/organization_invitations/\(invitationId)/accept")
      .method(.post)
      .addClerkSessionId()
      .data(type: ClientResponse<UserOrganizationInvitation>.self)
      .async()
      .response
  }
  
  // MARK: - Organization Suggestion Methods
  
  var acceptOrganizationSuggestion: (_ suggestionId: String) async throws -> OrganizationSuggestion = { suggestionId in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/organization_suggestions/\(suggestionId)/accept")
      .method(.post)
      .addClerkSessionId()
      .data(type: ClientResponse<OrganizationSuggestion>.self)
      .async()
      .response
  }
  
  // MARK: - Organization Membership Request Methods
  
  var acceptOrganizationMembershipRequest: (_ organizationId: String, _ requestId: String) async throws -> OrganizationMembershipRequest = { organizationId, requestId in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/membership_requests/\(requestId)/accept")
      .method(.post)
      .data(type: ClientResponse<OrganizationMembershipRequest>.self)
      .async()
      .response
  }
  
  var rejectOrganizationMembershipRequest: (_ organizationId: String, _ requestId: String) async throws -> OrganizationMembershipRequest = { organizationId, requestId in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/membership_requests/\(requestId)/reject")
      .method(.post)
      .data(type: ClientResponse<OrganizationMembershipRequest>.self)
      .async()
      .response
  }
  
} 
