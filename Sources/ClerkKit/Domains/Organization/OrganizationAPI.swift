//
//  OrganizationAPI.swift
//  Clerk
//

import Foundation

// swiftlint:disable:next type_body_length
package enum OrganizationAPI {
  package static func create(name: String, slug: String?) -> Request<ClientResponse<Organization>> {
    var body: [String: String] = ["name": name]
    if let slug {
      body["slug"] = slug
    }

    return Request(
      path: "/v1/organizations",
      method: .post,
      scopedToActiveSession: true,
      body: body
    )
  }

  package static func get(organizationId: String) -> Request<ClientResponse<Organization>> {
    Request(
      path: "/v1/organizations/\(organizationId)",
      method: .get,
      scopedToActiveSession: true
    )
  }

  package static func update(organizationId: String, name: String, slug: String?) -> Request<ClientResponse<Organization>> {
    Request(
      path: "/v1/organizations/\(organizationId)",
      method: .patch,
      scopedToActiveSession: true,
      body: [
        "name": name,
        "slug": slug,
      ]
    )
  }

  package static func destroy(organizationId: String) -> Request<ClientResponse<DeletedObject>> {
    Request(
      path: "/v1/organizations/\(organizationId)",
      method: .delete,
      scopedToActiveSession: true
    )
  }

  package static func setLogo(organizationId: String, boundary: String) -> Request<ClientResponse<Organization>> {
    Request(
      path: "/v1/organizations/\(organizationId)/logo",
      method: .put,
      headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
      scopedToActiveSession: true
    )
  }

  package static func deleteLogo(organizationId: String) -> Request<ClientResponse<DeletedObject>> {
    Request(
      path: "/v1/organizations/\(organizationId)/logo",
      method: .delete,
      scopedToActiveSession: true
    )
  }

  package static func getRoles(organizationId: String, offset: Int, pageSize: Int) -> Request<ClientResponse<ClerkPaginatedResponse<RoleResource>>> {
    Request(
      path: "/v1/organizations/\(organizationId)/roles",
      method: .get,
      scopedToActiveSession: true,
      query: [
        ("offset", value: String(offset)),
        ("limit", value: String(pageSize)),
      ]
    )
  }

  package static func getMemberships(
    organizationId: String,
    query: String?,
    role: [String]?,
    offset: Int,
    pageSize: Int
  ) -> Request<ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>> {
    var queryParams: [(String, String?)] = [
      ("offset", value: String(offset)),
      ("limit", value: String(pageSize)),
      ("paginated", value: String(true)),
    ]

    if let query {
      queryParams.append(("query", value: query))
    }

    if let role {
      queryParams += role.map { ("role[]", value: $0) }
    }

    return Request(
      path: "/v1/organizations/\(organizationId)/memberships",
      method: .get,
      scopedToActiveSession: true,
      query: queryParams
    )
  }

  package static func addMember(organizationId: String, userId: String, role: String) -> Request<ClientResponse<OrganizationMembership>> {
    Request(
      path: "/v1/organizations/\(organizationId)/memberships",
      method: .post,
      scopedToActiveSession: true,
      body: [
        "user_id": userId,
        "role": role,
      ]
    )
  }

  package static func updateMember(organizationId: String, userId: String, role: String) -> Request<ClientResponse<OrganizationMembership>> {
    Request(
      path: "/v1/organizations/\(organizationId)/memberships/\(userId)",
      method: .patch,
      scopedToActiveSession: true,
      body: ["role": role]
    )
  }

  package static func removeMember(organizationId: String, userId: String) -> Request<ClientResponse<OrganizationMembership>> {
    Request(
      path: "/v1/organizations/\(organizationId)/memberships/\(userId)",
      method: .delete,
      scopedToActiveSession: true
    )
  }

  package static func getInvitations(
    organizationId: String,
    offset: Int,
    pageSize: Int,
    status: [String]
  ) -> Request<ClientResponse<ClerkPaginatedResponse<OrganizationInvitation>>> {
    var queryParams: [(String, String?)] = [
      ("offset", value: String(offset)),
      ("limit", value: String(pageSize)),
    ]

    queryParams += status.map { ("status", $0 as String?) }

    return Request(
      path: "/v1/organizations/\(organizationId)/invitations",
      method: .get,
      scopedToActiveSession: true,
      query: queryParams
    )
  }

  package static func inviteMember(organizationId: String, emailAddress: String, role: String) -> Request<ClientResponse<OrganizationInvitation>> {
    Request(
      path: "/v1/organizations/\(organizationId)/invitations",
      method: .post,
      scopedToActiveSession: true,
      body: [
        "email_address": emailAddress,
        "role": role,
      ]
    )
  }

  package static func inviteMembers(organizationId: String, emailAddresses: [String], role: String) -> Request<ClientResponse<[OrganizationInvitation]>> {
    let bodyParams: [String: JSON] = [
      "email_address": .array(emailAddresses.map { .string($0) }),
      "role": .string(role),
    ]

    return Request(
      path: "/v1/organizations/\(organizationId)/invitations/bulk",
      method: .post,
      scopedToActiveSession: true,
      body: bodyParams
    )
  }

  package static func revokeInvitation(organizationId: String, invitationId: String) -> Request<ClientResponse<OrganizationInvitation>> {
    Request(
      path: "/v1/organizations/\(organizationId)/invitations/\(invitationId)/revoke",
      method: .post,
      scopedToActiveSession: true
    )
  }

  package static func createDomain(organizationId: String, domainName: String) -> Request<ClientResponse<OrganizationDomain>> {
    Request(
      path: "/v1/organizations/\(organizationId)/domains",
      method: .post,
      scopedToActiveSession: true,
      body: ["name": domainName]
    )
  }

  package static func getDomains(
    organizationId: String,
    offset: Int,
    pageSize: Int,
    enrollmentMode: String?
  ) -> Request<ClientResponse<ClerkPaginatedResponse<OrganizationDomain>>> {
    var queryParams: [(String, String?)] = [
      ("offset", value: String(offset)),
      ("limit", value: String(pageSize)),
    ]

    if let enrollmentMode {
      queryParams.append(("enrollment_mode", value: enrollmentMode))
    }

    return Request(
      path: "/v1/organizations/\(organizationId)/domains",
      method: .get,
      scopedToActiveSession: true,
      query: queryParams
    )
  }

  package static func getDomain(organizationId: String, domainId: String) -> Request<ClientResponse<OrganizationDomain>> {
    Request(
      path: "/v1/organizations/\(organizationId)/domains/\(domainId)",
      method: .get,
      scopedToActiveSession: true
    )
  }

  package static func deleteDomain(organizationId: String, domainId: String) -> Request<ClientResponse<DeletedObject>> {
    Request(
      path: "/v1/organizations/\(organizationId)/domains/\(domainId)",
      method: .delete,
      scopedToActiveSession: true
    )
  }

  package static func prepareDomainAffiliationVerification(
    organizationId: String,
    domainId: String,
    affiliationEmailAddress: String
  ) -> Request<ClientResponse<OrganizationDomain>> {
    Request(
      path: "/v1/organizations/\(organizationId)/domains/\(domainId)/prepare_affiliation_verification",
      method: .post,
      scopedToActiveSession: true,
      body: ["affiliation_email_address": affiliationEmailAddress]
    )
  }

  package static func attemptDomainAffiliationVerification(
    organizationId: String,
    domainId: String,
    code: String
  ) -> Request<ClientResponse<OrganizationDomain>> {
    Request(
      path: "/v1/organizations/\(organizationId)/domains/\(domainId)/attempt_affiliation_verification",
      method: .post,
      scopedToActiveSession: true,
      body: ["code": code]
    )
  }

  package static func updateDomainEnrollmentMode(
    organizationId: String,
    domainId: String,
    enrollmentMode: String,
    deletePending: Bool?
  ) -> Request<ClientResponse<OrganizationDomain>> {
    var bodyParams: [String: JSON] = [
      "enrollment_mode": .string(enrollmentMode),
    ]

    if let deletePending {
      bodyParams["delete_pending"] = .bool(deletePending)
    }

    return Request(
      path: "/v1/organizations/\(organizationId)/domains/\(domainId)/update_enrollment_mode",
      method: .post,
      scopedToActiveSession: true,
      body: bodyParams
    )
  }

  package static func getMembershipRequests(
    organizationId: String,
    offset: Int,
    pageSize: Int,
    status: String?
  ) -> Request<ClientResponse<ClerkPaginatedResponse<OrganizationMembershipRequest>>> {
    var queryParams: [(String, String?)] = [
      ("offset", value: String(offset)),
      ("limit", value: String(pageSize)),
    ]

    if let status {
      queryParams.append(("status", value: status))
    }

    return Request(
      path: "/v1/organizations/\(organizationId)/membership_requests",
      method: .get,
      scopedToActiveSession: true,
      query: queryParams
    )
  }

  package static func acceptMembershipRequest(organizationId: String, requestId: String) -> Request<ClientResponse<OrganizationMembershipRequest>> {
    Request(
      path: "/v1/organizations/\(organizationId)/membership_requests/\(requestId)/accept",
      method: .post,
      scopedToActiveSession: true
    )
  }

  package static func rejectMembershipRequest(organizationId: String, requestId: String) -> Request<ClientResponse<OrganizationMembershipRequest>> {
    Request(
      path: "/v1/organizations/\(organizationId)/membership_requests/\(requestId)/reject",
      method: .post,
      scopedToActiveSession: true
    )
  }

  package static func acceptUserInvitation(invitationId: String) -> Request<ClientResponse<UserOrganizationInvitation>> {
    Request(
      path: "/v1/me/organization_invitations/\(invitationId)/accept",
      method: .post,
      scopedToActiveSession: true
    )
  }

  package static func acceptSuggestion(suggestionId: String) -> Request<ClientResponse<OrganizationSuggestion>> {
    Request(
      path: "/v1/me/organization_suggestions/\(suggestionId)/accept",
      method: .post,
      scopedToActiveSession: true
    )
  }
}
