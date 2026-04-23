//
//  OrganizationService.swift
//  Clerk
//

import Foundation

protocol OrganizationServiceProtocol: Sendable {
  @MainActor func createOrganization(name: String, slug: String?, sessionId: String?) async throws -> Organization
  @MainActor func updateOrganization(organizationId: String, name: String, slug: String?, sessionId: String?) async throws -> Organization
  @MainActor func destroyOrganization(organizationId: String, sessionId: String?) async throws -> DeletedObject
  @MainActor func setOrganizationLogo(organizationId: String, imageData: Data, sessionId: String?) async throws -> Organization
  @MainActor func getOrganizationRoles(organizationId: String, initialPage: Int, pageSize: Int, sessionId: String?) async throws -> ClerkPaginatedResponse<RoleResource>
  @MainActor func getOrganizationMemberships(organizationId: String, query: String?, role: [String]?, initialPage: Int, pageSize: Int, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationMembership>
  @MainActor func addOrganizationMember(organizationId: String, userId: String, role: String, sessionId: String?) async throws -> OrganizationMembership
  @MainActor func updateOrganizationMember(organizationId: String, userId: String, role: String, sessionId: String?) async throws -> OrganizationMembership
  @MainActor func removeOrganizationMember(organizationId: String, userId: String, sessionId: String?) async throws -> OrganizationMembership
  @MainActor func getOrganizationInvitations(organizationId: String, initialPage: Int, pageSize: Int, status: String?, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationInvitation>
  @MainActor func inviteOrganizationMember(organizationId: String, emailAddress: String, role: String, sessionId: String?) async throws -> OrganizationInvitation
  @MainActor func createOrganizationDomain(organizationId: String, domainName: String, sessionId: String?) async throws -> OrganizationDomain
  @MainActor func getOrganizationDomains(organizationId: String, initialPage: Int, pageSize: Int, enrollmentMode: String?, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationDomain>
  @MainActor func getOrganizationDomain(organizationId: String, domainId: String, sessionId: String?) async throws -> OrganizationDomain
  @MainActor func getOrganizationMembershipRequests(organizationId: String, initialPage: Int, pageSize: Int, status: String?, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest>
  @MainActor func deleteOrganizationDomain(organizationId: String, domainId: String, sessionId: String?) async throws -> DeletedObject
  @MainActor func prepareOrganizationDomainAffiliationVerification(organizationId: String, domainId: String, affiliationEmailAddress: String, sessionId: String?) async throws -> OrganizationDomain
  @MainActor func attemptOrganizationDomainAffiliationVerification(organizationId: String, domainId: String, code: String, sessionId: String?) async throws -> OrganizationDomain
  @MainActor func revokeOrganizationInvitation(organizationId: String, invitationId: String, sessionId: String?) async throws -> OrganizationInvitation
  @MainActor func destroyOrganizationMembership(organizationId: String, userId: String, sessionId: String?) async throws -> OrganizationMembership
  @MainActor func acceptUserOrganizationInvitation(invitationId: String, sessionId: String?) async throws -> UserOrganizationInvitation
  @MainActor func acceptOrganizationSuggestion(suggestionId: String, sessionId: String?) async throws -> OrganizationSuggestion
  @MainActor func acceptOrganizationMembershipRequest(organizationId: String, requestId: String, sessionId: String?) async throws -> OrganizationMembershipRequest
  @MainActor func rejectOrganizationMembershipRequest(organizationId: String, requestId: String, sessionId: String?) async throws -> OrganizationMembershipRequest
}

// swiftlint:disable:next type_body_length
final class OrganizationService: OrganizationServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func createOrganization(name: String, slug: String?, sessionId: String?) async throws -> Organization {
    var body: [String: String] = ["name": name]
    if let slug {
      body["slug"] = slug
    }

    let request = Request<ClientResponse<Organization>>(
      path: "/v1/organizations",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: body
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func updateOrganization(organizationId: String, name: String, slug: String?, sessionId: String?) async throws -> Organization {
    let request = Request<ClientResponse<Organization>>(
      path: "/v1/organizations/\(organizationId)",
      method: .patch,
      query: [("_clerk_session_id", value: sessionId)],
      body: [
        "name": name,
        "slug": slug,
      ]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func destroyOrganization(organizationId: String, sessionId: String?) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/organizations/\(organizationId)",
      method: .delete,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func setOrganizationLogo(organizationId: String, imageData: Data, sessionId: String?) async throws -> Organization {
    let boundary = UUID().uuidString
    var data = Data()
    data.append(Data("\r\n--\(boundary)\r\n".utf8))
    data.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".utf8))
    data.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
    data.append(imageData)
    data.append(Data("\r\n--\(boundary)--\r\n".utf8))

    let request = Request<ClientResponse<Organization>>(
      path: "/v1/organizations/\(organizationId)/logo",
      method: .put,
      headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.upload(for: request, from: data).value.response
  }

  @MainActor
  func getOrganizationRoles(organizationId: String, initialPage: Int, pageSize: Int, sessionId: String?) async throws -> ClerkPaginatedResponse<RoleResource> {
    let request = Request<ClientResponse<ClerkPaginatedResponse<RoleResource>>>(
      path: "/v1/organizations/\(organizationId)/roles",
      method: .get,
      query: [
        ("_clerk_session_id", value: sessionId),
        ("offset", value: String(initialPage)),
        ("limit", value: String(pageSize)),
      ]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getOrganizationMemberships(organizationId: String, query: String?, role: [String]?, initialPage: Int, pageSize: Int, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    var queryParams: [(String, String?)] = [
      ("_clerk_session_id", value: sessionId),
      ("offset", value: String(initialPage)),
      ("limit", value: String(pageSize)),
      ("paginated", value: String(true)),
    ]

    if let query {
      queryParams.append(("query", value: query))
    }

    if let role {
      queryParams += role.map { ("role[]", value: $0) }
    }

    let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>>(
      path: "/v1/organizations/\(organizationId)/memberships",
      method: .get,
      query: queryParams
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func addOrganizationMember(organizationId: String, userId: String, role: String, sessionId: String?) async throws -> OrganizationMembership {
    let request = Request<ClientResponse<OrganizationMembership>>(
      path: "/v1/organizations/\(organizationId)/memberships",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: [
        "user_id": userId,
        "role": role,
      ]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func updateOrganizationMember(organizationId: String, userId: String, role: String, sessionId: String?) async throws -> OrganizationMembership {
    let request = Request<ClientResponse<OrganizationMembership>>(
      path: "/v1/organizations/\(organizationId)/memberships/\(userId)",
      method: .patch,
      query: [("_clerk_session_id", value: sessionId)],
      body: ["role": role]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func removeOrganizationMember(organizationId: String, userId: String, sessionId: String?) async throws -> OrganizationMembership {
    let request = Request<ClientResponse<OrganizationMembership>>(
      path: "/v1/organizations/\(organizationId)/memberships/\(userId)",
      method: .delete,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getOrganizationInvitations(organizationId: String, initialPage: Int, pageSize: Int, status: String?, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationInvitation> {
    var queryParams: [(String, String?)] = [
      ("_clerk_session_id", value: sessionId),
      ("offset", value: String(initialPage)),
      ("limit", value: String(pageSize)),
      ("paginated", value: String(true)),
    ]

    if let status {
      queryParams.append(("status", value: status))
    }

    let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationInvitation>>>(
      path: "/v1/organizations/\(organizationId)/invitations",
      method: .get,
      query: queryParams
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func inviteOrganizationMember(organizationId: String, emailAddress: String, role: String, sessionId: String?) async throws -> OrganizationInvitation {
    let request = Request<ClientResponse<OrganizationInvitation>>(
      path: "/v1/organizations/\(organizationId)/invitations",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: [
        "email_address": emailAddress,
        "role": role,
      ]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func createOrganizationDomain(organizationId: String, domainName: String, sessionId: String?) async throws -> OrganizationDomain {
    let request = Request<ClientResponse<OrganizationDomain>>(
      path: "/v1/organizations/\(organizationId)/domains",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: ["name": domainName]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getOrganizationDomains(organizationId: String, initialPage: Int, pageSize: Int, enrollmentMode: String?, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationDomain> {
    var queryParams: [(String, String?)] = [
      ("_clerk_session_id", value: sessionId),
      ("offset", value: String(initialPage)),
      ("limit", value: String(pageSize)),
    ]

    if let enrollmentMode {
      queryParams.append(("enrollment_mode", value: enrollmentMode))
    }

    let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationDomain>>>(
      path: "/v1/organizations/\(organizationId)/domains",
      method: .get,
      query: queryParams
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getOrganizationDomain(organizationId: String, domainId: String, sessionId: String?) async throws -> OrganizationDomain {
    let request = Request<ClientResponse<OrganizationDomain>>(
      path: "/v1/organizations/\(organizationId)/domains/\(domainId)",
      method: .get,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getOrganizationMembershipRequests(organizationId: String, initialPage: Int, pageSize: Int, status: String?, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest> {
    var queryParams: [(String, String?)] = [
      ("_clerk_session_id", value: sessionId),
      ("offset", value: String(initialPage)),
      ("limit", value: String(pageSize)),
    ]

    if let status {
      queryParams.append(("status", value: status))
    }

    let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationMembershipRequest>>>(
      path: "/v1/organizations/\(organizationId)/membership_requests",
      method: .get,
      query: queryParams
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func deleteOrganizationDomain(organizationId: String, domainId: String, sessionId: String?) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/organizations/\(organizationId)/domains/\(domainId)",
      method: .delete,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func prepareOrganizationDomainAffiliationVerification(organizationId: String, domainId: String, affiliationEmailAddress: String, sessionId: String?) async throws -> OrganizationDomain {
    let request = Request<ClientResponse<OrganizationDomain>>(
      path: "/v1/organizations/\(organizationId)/domains/\(domainId)/prepare_affiliation_verification",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: ["affiliation_email_address": affiliationEmailAddress]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptOrganizationDomainAffiliationVerification(organizationId: String, domainId: String, code: String, sessionId: String?) async throws -> OrganizationDomain {
    let request = Request<ClientResponse<OrganizationDomain>>(
      path: "/v1/organizations/\(organizationId)/domains/\(domainId)/attempt_affiliation_verification",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: ["code": code]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func revokeOrganizationInvitation(organizationId: String, invitationId: String, sessionId: String?) async throws -> OrganizationInvitation {
    let request = Request<ClientResponse<OrganizationInvitation>>(
      path: "/v1/organizations/\(organizationId)/invitations/\(invitationId)/revoke",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func destroyOrganizationMembership(organizationId: String, userId: String, sessionId: String?) async throws -> OrganizationMembership {
    let request = Request<ClientResponse<OrganizationMembership>>(
      path: "/v1/organizations/\(organizationId)/memberships/\(userId)",
      method: .delete,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func acceptUserOrganizationInvitation(invitationId: String, sessionId: String?) async throws -> UserOrganizationInvitation {
    let request = Request<ClientResponse<UserOrganizationInvitation>>(
      path: "/v1/me/organization_invitations/\(invitationId)/accept",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func acceptOrganizationSuggestion(suggestionId: String, sessionId: String?) async throws -> OrganizationSuggestion {
    let request = Request<ClientResponse<OrganizationSuggestion>>(
      path: "/v1/me/organization_suggestions/\(suggestionId)/accept",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func acceptOrganizationMembershipRequest(organizationId: String, requestId: String, sessionId: String?) async throws -> OrganizationMembershipRequest {
    let request = Request<ClientResponse<OrganizationMembershipRequest>>(
      path: "/v1/organizations/\(organizationId)/membership_requests/\(requestId)/accept",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func rejectOrganizationMembershipRequest(organizationId: String, requestId: String, sessionId: String?) async throws -> OrganizationMembershipRequest {
    let request = Request<ClientResponse<OrganizationMembershipRequest>>(
      path: "/v1/organizations/\(organizationId)/membership_requests/\(requestId)/reject",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }
}
