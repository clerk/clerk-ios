//
//  OrganizationService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation
import Get

extension Container {

    var organizationService: Factory<OrganizationServiceProtocol> {
        self { OrganizationService() }
    }

}

protocol OrganizationServiceProtocol: Sendable {
    @MainActor func updateOrganization(_ organizationId: String, _ name: String, _ slug: String?) async throws -> Organization
    @MainActor func destroyOrganization(_ organizationId: String) async throws -> DeletedObject
    @MainActor func setOrganizationLogo(_ organizationId: String, _ imageData: Data) async throws -> Organization
    @MainActor func getOrganizationRoles(_ organizationId: String, _ initialPage: Int, _ pageSize: Int) async throws -> ClerkPaginatedResponse<RoleResource>
    @MainActor func getOrganizationMemberships(_ organizationId: String, _ query: String?, _ role: [String]?, _ initialPage: Int, _ pageSize: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>
    @MainActor func addOrganizationMember(_ organizationId: String, _ userId: String, _ role: String) async throws -> OrganizationMembership
    @MainActor func updateOrganizationMember(_ organizationId: String, _ userId: String, _ role: String) async throws -> OrganizationMembership
    @MainActor func removeOrganizationMember(_ organizationId: String, _ userId: String) async throws -> OrganizationMembership
    @MainActor func getOrganizationInvitations(_ organizationId: String, _ initialPage: Int, _ pageSize: Int, _ status: String?) async throws -> ClerkPaginatedResponse<OrganizationInvitation>
    @MainActor func inviteOrganizationMember(_ organizationId: String, _ emailAddress: String, _ role: String) async throws -> OrganizationInvitation
    @MainActor func createOrganizationDomain(_ organizationId: String, _ domainName: String) async throws -> OrganizationDomain
    @MainActor func getOrganizationDomains(_ organizationId: String, _ initialPage: Int, _ pageSize: Int, _ enrollmentMode: String?) async throws -> ClerkPaginatedResponse<OrganizationDomain>
    @MainActor func getOrganizationDomain(_ organizationId: String, _ domainId: String) async throws -> OrganizationDomain
    @MainActor func getOrganizationMembershipRequests(_ organizationId: String, _ initialPage: Int, _ pageSize: Int, _ status: String?) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest>
    @MainActor func deleteOrganizationDomain(_ organizationId: String, _ domainId: String) async throws -> DeletedObject
    @MainActor func prepareOrganizationDomainAffiliationVerification(_ organizationId: String, _ domainId: String, _ affiliationEmailAddress: String) async throws -> OrganizationDomain
    @MainActor func attemptOrganizationDomainAffiliationVerification(_ organizationId: String, _ domainId: String, _ code: String) async throws -> OrganizationDomain
    @MainActor func revokeOrganizationInvitation(_ organizationId: String, _ invitationId: String) async throws -> OrganizationInvitation
    @MainActor func destroyOrganizationMembership(_ organizationId: String, _ userId: String) async throws -> OrganizationMembership
    @MainActor func acceptUserOrganizationInvitation(_ invitationId: String) async throws -> UserOrganizationInvitation
    @MainActor func acceptOrganizationSuggestion(_ suggestionId: String) async throws -> OrganizationSuggestion
    @MainActor func acceptOrganizationMembershipRequest(_ organizationId: String, _ requestId: String) async throws -> OrganizationMembershipRequest
    @MainActor func rejectOrganizationMembershipRequest(_ organizationId: String, _ requestId: String) async throws -> OrganizationMembershipRequest
}

final class OrganizationService: OrganizationServiceProtocol {

    private var apiClient: APIClient { Container.shared.apiClient() }

    @MainActor
    func updateOrganization(_ organizationId: String, _ name: String, _ slug: String?) async throws -> Organization {
        let request = Request<ClientResponse<Organization>>(
            path: "/v1/organizations/\(organizationId)",
            method: .patch,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "name": name,
                "slug": slug
            ]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func destroyOrganization(_ organizationId: String) async throws -> DeletedObject {
        let request = Request<ClientResponse<DeletedObject>>(
            path: "/v1/organizations/\(organizationId)",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func setOrganizationLogo(_ organizationId: String, _ imageData: Data) async throws -> Organization {
        let boundary = UUID().uuidString
        var data = Data()
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        data.append(imageData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let request = Request<ClientResponse<Organization>>(
            path: "/v1/organizations/\(organizationId)/logo",
            method: .put,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
        )

        return try await apiClient.upload(for: request, from: data).value.response
    }

    @MainActor
    func getOrganizationRoles(_ organizationId: String, _ initialPage: Int, _ pageSize: Int) async throws -> ClerkPaginatedResponse<RoleResource> {
        let request = Request<ClientResponse<ClerkPaginatedResponse<RoleResource>>>(
            path: "/v1/organizations/\(organizationId)/roles",
            method: .get,
            query: [
                ("_clerk_session_id", value: Clerk.shared.session?.id),
                ("offset", value: String(initialPage)),
                ("limit", value: String(pageSize))
            ]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func getOrganizationMemberships(_ organizationId: String, _ query: String?, _ role: [String]?, _ initialPage: Int, _ pageSize: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
        var queryParams: [(String, String?)] = [
            ("_clerk_session_id", value: Clerk.shared.session?.id),
            ("offset", value: String(initialPage)),
            ("limit", value: String(pageSize)),
            ("paginated", value: String(true))
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
    func addOrganizationMember(_ organizationId: String, _ userId: String, _ role: String) async throws -> OrganizationMembership {
        let request = Request<ClientResponse<OrganizationMembership>>(
            path: "/v1/organizations/\(organizationId)/memberships",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "user_id": userId,
                "role": role
            ]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func updateOrganizationMember(_ organizationId: String, _ userId: String, _ role: String) async throws -> OrganizationMembership {
        let request = Request<ClientResponse<OrganizationMembership>>(
            path: "/v1/organizations/\(organizationId)/memberships/\(userId)",
            method: .patch,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["role": role]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func removeOrganizationMember(_ organizationId: String, _ userId: String) async throws -> OrganizationMembership {
        let request = Request<ClientResponse<OrganizationMembership>>(
            path: "/v1/organizations/\(organizationId)/memberships/\(userId)",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func getOrganizationInvitations(_ organizationId: String, _ initialPage: Int, _ pageSize: Int, _ status: String?) async throws -> ClerkPaginatedResponse<OrganizationInvitation> {
        var queryParams: [(String, String?)] = [
            ("_clerk_session_id", value: Clerk.shared.session?.id),
            ("offset", value: String(initialPage)),
            ("limit", value: String(pageSize)),
            ("paginated", value: String(true))
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
    func inviteOrganizationMember(_ organizationId: String, _ emailAddress: String, _ role: String) async throws -> OrganizationInvitation {
        let request = Request<ClientResponse<OrganizationInvitation>>(
            path: "/v1/organizations/\(organizationId)/invitations",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "email_address": emailAddress,
                "role": role
            ]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func createOrganizationDomain(_ organizationId: String, _ domainName: String) async throws -> OrganizationDomain {
        let request = Request<ClientResponse<OrganizationDomain>>(
            path: "/v1/organizations/\(organizationId)/domains",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["name": domainName]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func getOrganizationDomains(_ organizationId: String, _ initialPage: Int, _ pageSize: Int, _ enrollmentMode: String?) async throws -> ClerkPaginatedResponse<OrganizationDomain> {
        var queryParams: [(String, String?)] = [
            ("_clerk_session_id", value: Clerk.shared.session?.id),
            ("offset", value: String(initialPage)),
            ("limit", value: String(pageSize))
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
    func getOrganizationDomain(_ organizationId: String, _ domainId: String) async throws -> OrganizationDomain {
        let request = Request<ClientResponse<OrganizationDomain>>(
            path: "/v1/organizations/\(organizationId)/domains/\(domainId)",
            method: .get,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func getOrganizationMembershipRequests(_ organizationId: String, _ initialPage: Int, _ pageSize: Int, _ status: String?) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest> {
        var queryParams: [(String, String?)] = [
            ("_clerk_session_id", value: Clerk.shared.session?.id),
            ("offset", value: String(initialPage)),
            ("limit", value: String(pageSize))
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
    func deleteOrganizationDomain(_ organizationId: String, _ domainId: String) async throws -> DeletedObject {
        let request = Request<ClientResponse<DeletedObject>>(
            path: "/v1/organizations/\(organizationId)/domains/\(domainId)",
            method: .delete
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func prepareOrganizationDomainAffiliationVerification(_ organizationId: String, _ domainId: String, _ affiliationEmailAddress: String) async throws -> OrganizationDomain {
        let request = Request<ClientResponse<OrganizationDomain>>(
            path: "/v1/organizations/\(organizationId)/domains/\(domainId)/prepare_affiliation_verification",
            method: .post,
            body: ["affiliation_email_address": affiliationEmailAddress]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func attemptOrganizationDomainAffiliationVerification(_ organizationId: String, _ domainId: String, _ code: String) async throws -> OrganizationDomain {
        let request = Request<ClientResponse<OrganizationDomain>>(
            path: "/v1/organizations/\(organizationId)/domains/\(domainId)/attempt_affiliation_verification",
            method: .post,
            body: ["code": code]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func revokeOrganizationInvitation(_ organizationId: String, _ invitationId: String) async throws -> OrganizationInvitation {
        let request = Request<ClientResponse<OrganizationInvitation>>(
            path: "/v1/organizations/\(organizationId)/invitations/\(invitationId)/revoke",
            method: .post
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func destroyOrganizationMembership(_ organizationId: String, _ userId: String) async throws -> OrganizationMembership {
        let request = Request<ClientResponse<OrganizationMembership>>(
            path: "/v1/organizations/\(organizationId)/memberships/\(userId)",
            method: .delete
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func acceptUserOrganizationInvitation(_ invitationId: String) async throws -> UserOrganizationInvitation {
        let request = Request<ClientResponse<UserOrganizationInvitation>>(
            path: "/v1/me/organization_invitations/\(invitationId)/accept",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func acceptOrganizationSuggestion(_ suggestionId: String) async throws -> OrganizationSuggestion {
        let request = Request<ClientResponse<OrganizationSuggestion>>(
            path: "/v1/me/organization_suggestions/\(suggestionId)/accept",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func acceptOrganizationMembershipRequest(_ organizationId: String, _ requestId: String) async throws -> OrganizationMembershipRequest {
        let request = Request<ClientResponse<OrganizationMembershipRequest>>(
            path: "/v1/organizations/\(organizationId)/membership_requests/\(requestId)/accept",
            method: .post
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func rejectOrganizationMembershipRequest(_ organizationId: String, _ requestId: String) async throws -> OrganizationMembershipRequest {
        let request = Request<ClientResponse<OrganizationMembershipRequest>>(
            path: "/v1/organizations/\(organizationId)/membership_requests/\(requestId)/reject",
            method: .post
        )

        return try await apiClient.send(request).value.response
    }
}
