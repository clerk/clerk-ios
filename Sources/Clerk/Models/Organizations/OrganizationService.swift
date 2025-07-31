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

    var organizationService: Factory<OrganizationService> {
        self { OrganizationService() }
    }

}

struct OrganizationService {

    // MARK: - Organization Methods

    var updateOrganization: @MainActor (_ organizationId: String, _ name: String, _ slug: String?) async throws -> Organization = { organizationId, name, slug in
        let request = Request<ClientResponse<Organization>>.init(
            path: "/v1/organizations/\(organizationId)",
            method: .patch,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "name": name,
                "slug": slug
            ]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var destroyOrganization: @MainActor (_ organizationId: String) async throws -> DeletedObject = { organizationId in
        let request = Request<ClientResponse<DeletedObject>>.init(
            path: "/v1/organizations/\(organizationId)",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var setOrganizationLogo: @MainActor (_ organizationId: String, _ imageData: Data) async throws -> Organization = { organizationId, imageData in
        let boundary = UUID().uuidString
        var data = Data()
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        data.append(imageData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = Request<ClientResponse<Organization>>.init(
            path: "/v1/organizations/\(organizationId)/logo",
            method: .put,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: data,
            headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var getOrganizationRoles: @MainActor (_ organizationId: String, _ initialPage: Int, _ pageSize: Int) async throws -> ClerkPaginatedResponse<RoleResource> = { organizationId, initialPage, pageSize in
        let request = Request<ClientResponse<ClerkPaginatedResponse<RoleResource>>>.init(
            path: "/v1/organizations/\(organizationId)/roles",
            method: .get,
            query: [
                ("_clerk_session_id", value: Clerk.shared.session?.id),
                ("offset", value: String(initialPage)),
                ("limit", value: String(pageSize))
            ]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var getOrganizationMemberships: @MainActor (_ organizationId: String, _ query: String?, _ role: [String]?, _ initialPage: Int, _ pageSize: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership> = { organizationId, query, role, initialPage, pageSize in
        var queryParams: [(String, String?)] = [
            ("_clerk_session_id", value: Clerk.shared.session?.id),
            ("offset", value: String(initialPage)),
            ("limit", value: String(pageSize)),
            ("paginated", value: String(true))
        ]
        
        if let query = query {
            queryParams.append(("query", value: query))
        }
        
        if let role = role {
            queryParams += role.map { ("role[]", value: $0) }
        }
        
        let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>>.init(
            path: "/v1/organizations/\(organizationId)/memberships",
            method: .get,
            query: queryParams
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var addOrganizationMember: @MainActor (_ organizationId: String, _ userId: String, _ role: String) async throws -> OrganizationMembership = { organizationId, userId, role in
        let request = Request<ClientResponse<OrganizationMembership>>.init(
            path: "/v1/organizations/\(organizationId)/memberships",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "user_id": userId,
                "role": role
            ]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var updateOrganizationMember: @MainActor (_ organizationId: String, _ userId: String, _ role: String) async throws -> OrganizationMembership = { organizationId, userId, role in
        let request = Request<ClientResponse<OrganizationMembership>>.init(
            path: "/v1/organizations/\(organizationId)/memberships/\(userId)",
            method: .patch,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "role": role
            ]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var removeOrganizationMember: @MainActor (_ organizationId: String, _ userId: String) async throws -> OrganizationMembership = { organizationId, userId in
        let request = Request<ClientResponse<OrganizationMembership>>.init(
            path: "/v1/organizations/\(organizationId)/memberships/\(userId)",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var getOrganizationInvitations: @MainActor (_ organizationId: String, _ initialPage: Int, _ pageSize: Int, _ status: String?) async throws -> ClerkPaginatedResponse<OrganizationInvitation> = { organizationId, initialPage, pageSize, status in
        var queryParams: [(String, String?)] = [
            ("_clerk_session_id", value: Clerk.shared.session?.id),
            ("offset", value: String(initialPage)),
            ("limit", value: String(pageSize)),
            ("paginated", value: String(true))
        ]
        
        if let status = status {
            queryParams.append(("status", value: status))
        }
        
        let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationInvitation>>>.init(
            path: "/v1/organizations/\(organizationId)/invitations",
            method: .get,
            query: queryParams
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var inviteOrganizationMember: @MainActor (_ organizationId: String, _ emailAddress: String, _ role: String) async throws -> OrganizationInvitation = { organizationId, emailAddress, role in
        let request = Request<ClientResponse<OrganizationInvitation>>.init(
            path: "/v1/organizations/\(organizationId)/invitations",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "email_address": emailAddress,
                "role": role
            ]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var createOrganizationDomain: @MainActor (_ organizationId: String, _ domainName: String) async throws -> OrganizationDomain = { organizationId, domainName in
        let request = Request<ClientResponse<OrganizationDomain>>.init(
            path: "/v1/organizations/\(organizationId)/domains",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "name": domainName
            ]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var getOrganizationDomains: @MainActor (_ organizationId: String, _ initialPage: Int, _ pageSize: Int, _ enrollmentMode: String?) async throws -> ClerkPaginatedResponse<OrganizationDomain> = { organizationId, initialPage, pageSize, enrollmentMode in
        var queryParams: [(String, String?)] = [
            ("_clerk_session_id", value: Clerk.shared.session?.id),
            ("offset", value: String(initialPage)),
            ("limit", value: String(pageSize))
        ]
        
        if let enrollmentMode = enrollmentMode {
            queryParams.append(("enrollment_mode", value: enrollmentMode))
        }
        
        let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationDomain>>>.init(
            path: "/v1/organizations/\(organizationId)/domains",
            method: .get,
            query: queryParams
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var getOrganizationDomain: @MainActor (_ organizationId: String, _ domainId: String) async throws -> OrganizationDomain = { organizationId, domainId in
        let request = Request<ClientResponse<OrganizationDomain>>.init(
            path: "/v1/organizations/\(organizationId)/domains/\(domainId)",
            method: .get,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var getOrganizationMembershipRequests: @MainActor (_ organizationId: String, _ initialPage: Int, _ pageSize: Int, _ status: String?) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest> = { organizationId, initialPage, pageSize, status in
        var queryParams: [(String, String?)] = [
            ("_clerk_session_id", value: Clerk.shared.session?.id),
            ("offset", value: String(initialPage)),
            ("limit", value: String(pageSize))
        ]
        
        if let status = status {
            queryParams.append(("status", value: status))
        }
        
        let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationMembershipRequest>>>.init(
            path: "/v1/organizations/\(organizationId)/membership_requests",
            method: .get,
            query: queryParams
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    // MARK: - Organization Domain Methods

    var deleteOrganizationDomain: @MainActor (_ organizationId: String, _ domainId: String) async throws -> DeletedObject = { organizationId, domainId in
        let request = Request<ClientResponse<DeletedObject>>.init(
            path: "/v1/organizations/\(organizationId)/domains/\(domainId)",
            method: .delete
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var prepareOrganizationDomainAffiliationVerification: @MainActor (_ organizationId: String, _ domainId: String, _ affiliationEmailAddress: String) async throws -> OrganizationDomain = { organizationId, domainId, affiliationEmailAddress in
        let request = Request<ClientResponse<OrganizationDomain>>.init(
            path: "/v1/organizations/\(organizationId)/domains/\(domainId)/prepare_affiliation_verification",
            method: .post,
            body: ["affiliation_email_address": affiliationEmailAddress]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var attemptOrganizationDomainAffiliationVerification: @MainActor (_ organizationId: String, _ domainId: String, _ code: String) async throws -> OrganizationDomain = { organizationId, domainId, code in
        let request = Request<ClientResponse<OrganizationDomain>>.init(
            path: "/v1/organizations/\(organizationId)/domains/\(domainId)/attempt_affiliation_verification",
            method: .post,
            body: ["code": code]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    // MARK: - Organization Invitation Methods

    var revokeOrganizationInvitation: @MainActor (_ organizationId: String, _ invitationId: String) async throws -> OrganizationInvitation = { organizationId, invitationId in
        let request = Request<ClientResponse<OrganizationInvitation>>.init(
            path: "/v1/organizations/\(organizationId)/invitations/\(invitationId)/revoke",
            method: .post
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    // MARK: - Organization Membership Methods

    var destroyOrganizationMembership: @MainActor (_ organizationId: String, _ userId: String) async throws -> OrganizationMembership = { organizationId, userId in
        let request = Request<ClientResponse<OrganizationMembership>>.init(
            path: "/v1/organizations/\(organizationId)/memberships/\(userId)",
            method: .delete
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var updateOrganizationMembership: @MainActor (_ organizationId: String, _ userId: String, _ role: String) async throws -> OrganizationMembership = { organizationId, userId, role in
        let request = Request<ClientResponse<OrganizationMembership>>.init(
            path: "/v1/organizations/\(organizationId)/memberships/\(userId)",
            method: .patch,
            body: ["role": role]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    // MARK: - User Organization Invitation Methods

    var acceptUserOrganizationInvitation: @MainActor (_ invitationId: String) async throws -> UserOrganizationInvitation = { invitationId in
        let request = Request<ClientResponse<UserOrganizationInvitation>>.init(
            path: "/v1/me/organization_invitations/\(invitationId)/accept",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    // MARK: - Organization Suggestion Methods

    var acceptOrganizationSuggestion: @MainActor (_ suggestionId: String) async throws -> OrganizationSuggestion = { suggestionId in
        let request = Request<ClientResponse<OrganizationSuggestion>>.init(
            path: "/v1/me/organization_suggestions/\(suggestionId)/accept",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    // MARK: - Organization Membership Request Methods

    var acceptOrganizationMembershipRequest: @MainActor (_ organizationId: String, _ requestId: String) async throws -> OrganizationMembershipRequest = { organizationId, requestId in
        let request = Request<ClientResponse<OrganizationMembershipRequest>>.init(
            path: "/v1/organizations/\(organizationId)/membership_requests/\(requestId)/accept",
            method: .post
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var rejectOrganizationMembershipRequest: @MainActor (_ organizationId: String, _ requestId: String) async throws -> OrganizationMembershipRequest = { organizationId, requestId in
        let request = Request<ClientResponse<OrganizationMembershipRequest>>.init(
            path: "/v1/organizations/\(organizationId)/membership_requests/\(requestId)/reject",
            method: .post
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

}
