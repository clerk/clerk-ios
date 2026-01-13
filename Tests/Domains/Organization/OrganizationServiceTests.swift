import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct OrganizationServiceTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func updateOrganization() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: organization, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["name"] == "New Name")
      #expect(request.urlEncodedFormBody!["slug"] == "new-slug")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.updateOrganization(
      organizationId: organization.id,
      name: "New Name",
      slug: "new-slug"
    )
    #expect(requestHandled.value)
  }

  @Test
  func destroyOrganization() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.destroyOrganization(organizationId: organization.id)
    #expect(requestHandled.value)
  }

  @Test
  func setOrganizationLogo() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/logo")!
    let imageData = Data("fake image data".utf8)

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .put: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: organization, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PUT")
      #expect(request.allHTTPHeaderFields?["Content-Type"]?.contains("multipart/form-data") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.setOrganizationLogo(
      organizationId: organization.id,
      imageData: imageData
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationRoles() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/roles")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<RoleResource>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.getOrganizationRoles(
      organizationId: organization.id,
      initialPage: 0,
      pageSize: 10
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMemberships() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>(
            response: ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      #expect(request.url?.query?.contains("paginated=true") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.getOrganizationMemberships(
      organizationId: organization.id,
      query: nil,
      role: nil,
      initialPage: 0,
      pageSize: 10
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMembershipsWithQuery() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>(
            response: ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("query=test") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.getOrganizationMemberships(
      organizationId: organization.id,
      query: "test",
      role: nil,
      initialPage: 0,
      pageSize: 10
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMembershipsWithRole() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>(
            response: ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      let queryString = request.url?.query ?? ""
      #expect(queryString.contains("role") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.getOrganizationMemberships(
      organizationId: organization.id,
      query: nil,
      role: ["admin"],
      initialPage: 0,
      pageSize: 10
    )
    #expect(requestHandled.value)
  }

  @Test
  func addOrganizationMember() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["user_id"] == "user123")
      #expect(request.urlEncodedFormBody!["role"] == "org:member")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.addOrganizationMember(
      organizationId: organization.id,
      userId: "user123",
      role: "org:member"
    )
    #expect(requestHandled.value)
  }

  @Test
  func updateOrganizationMember() async throws {
    let organization = Organization.mock
    let membership = OrganizationMembership.mockWithUserData
    let userId = membership.publicUserData!.userId!
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships/\(userId)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["role"] == "org:admin")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.updateOrganizationMember(
      organizationId: organization.id,
      userId: userId,
      role: "org:admin"
    )
    #expect(requestHandled.value)
  }

  @Test
  func removeOrganizationMember() async throws {
    let organization = Organization.mock
    let membership = OrganizationMembership.mockWithUserData
    let userId = membership.publicUserData!.userId!
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships/\(userId)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.removeOrganizationMember(
      organizationId: organization.id,
      userId: userId
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationInvitations() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/invitations")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationInvitation>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      #expect(request.url?.query?.contains("paginated=true") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.getOrganizationInvitations(
      organizationId: organization.id,
      initialPage: 0,
      pageSize: 10,
      status: nil
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationInvitationsWithStatus() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/invitations")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationInvitation>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("status=pending") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.getOrganizationInvitations(
      organizationId: organization.id,
      initialPage: 0,
      pageSize: 10,
      status: "pending"
    )
    #expect(requestHandled.value)
  }

  @Test
  func inviteOrganizationMember() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/invitations")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationInvitation>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["email_address"] == "user@example.com")
      #expect(request.urlEncodedFormBody!["role"] == "org:member")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.inviteOrganizationMember(
      organizationId: organization.id,
      emailAddress: "user@example.com",
      role: "org:member"
    )
    #expect(requestHandled.value)
  }

  @Test
  func createOrganizationDomain() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/domains")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["name"] == "example.com")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.createOrganizationDomain(
      organizationId: organization.id,
      domainName: "example.com"
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationDomains() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/domains")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationDomain>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.getOrganizationDomains(
      organizationId: organization.id,
      initialPage: 0,
      pageSize: 10,
      enrollmentMode: nil
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationDomainsWithEnrollmentMode() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/domains")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationDomain>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("enrollment_mode=automatic") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.getOrganizationDomains(
      organizationId: organization.id,
      initialPage: 0,
      pageSize: 10,
      enrollmentMode: "automatic"
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationDomain() async throws {
    let organization = Organization.mock
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/domains/\(domain.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.getOrganizationDomain(
      organizationId: organization.id,
      domainId: domain.id
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMembershipRequests() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/membership_requests")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationMembershipRequest>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.getOrganizationMembershipRequests(
      organizationId: organization.id,
      initialPage: 0,
      pageSize: 10,
      status: nil
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMembershipRequestsWithStatus() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/membership_requests")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationMembershipRequest>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("status=pending") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.getOrganizationMembershipRequests(
      organizationId: organization.id,
      initialPage: 0,
      pageSize: 10,
      status: "pending"
    )
    #expect(requestHandled.value)
  }

  @Test
  func deleteOrganizationDomain() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.deleteOrganizationDomain(
      organizationId: domain.organizationId,
      domainId: domain.id
    )
    #expect(requestHandled.value)
  }

  @Test
  func prepareOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/prepare_affiliation_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["affiliation_email_address"] == "user@example.com")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.prepareOrganizationDomainAffiliationVerification(
      organizationId: domain.organizationId,
      domainId: domain.id,
      affiliationEmailAddress: "user@example.com"
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/attempt_affiliation_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.attemptOrganizationDomainAffiliationVerification(
      organizationId: domain.organizationId,
      domainId: domain.id,
      code: "123456"
    )
    #expect(requestHandled.value)
  }

  @Test
  func revokeOrganizationInvitation() async throws {
    let invitation = OrganizationInvitation.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(invitation.organizationId)/invitations/\(invitation.id)/revoke")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationInvitation>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.revokeOrganizationInvitation(
      organizationId: invitation.organizationId,
      invitationId: invitation.id
    )
    #expect(requestHandled.value)
  }

  @Test
  func destroyOrganizationMembership() async throws {
    let membership = OrganizationMembership.mockWithUserData
    let userId = membership.publicUserData!.userId!
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(membership.organization.id)/memberships/\(userId)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.destroyOrganizationMembership(
      organizationId: membership.organization.id,
      userId: userId
    )
    #expect(requestHandled.value)
  }

  @Test
  func acceptUserOrganizationInvitation() async throws {
    let invitation = UserOrganizationInvitation.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/organization_invitations/\(invitation.id)/accept")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<UserOrganizationInvitation>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.acceptUserOrganizationInvitation(
      invitationId: invitation.id
    )
    #expect(requestHandled.value)
  }

  @Test
  func acceptOrganizationSuggestion() async throws {
    let suggestion = OrganizationSuggestion.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/organization_suggestions/\(suggestion.id)/accept")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationSuggestion>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.acceptOrganizationSuggestion(
      suggestionId: suggestion.id
    )
    #expect(requestHandled.value)
  }

  @Test
  func acceptOrganizationMembershipRequest() async throws {
    let request = OrganizationMembershipRequest.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(request.organizationId)/membership_requests/\(request.id)/accept")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembershipRequest>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.acceptOrganizationMembershipRequest(
      organizationId: request.organizationId,
      requestId: request.id
    )
    #expect(requestHandled.value)
  }

  @Test
  func rejectOrganizationMembershipRequest() async throws {
    let request = OrganizationMembershipRequest.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(request.organizationId)/membership_requests/\(request.id)/reject")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembershipRequest>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.rejectOrganizationMembershipRequest(
      organizationId: request.organizationId,
      requestId: request.id
    )
    #expect(requestHandled.value)
  }
}
