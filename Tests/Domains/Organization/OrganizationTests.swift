import FactoryTesting
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct OrganizationTests {

  init() {
    configureClerkForTesting()
  }

  @Test(.container)
  func testUpdateOrganization() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: organization, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["name"] == "New Name")
      #expect(request.urlEncodedFormBody!["slug"] == "new-slug")
      requestHandled.setValue(true)
    }
    mock.register()

    try await organization.update(name: "New Name", slug: "new-slug")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testDestroyOrganization() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.destroy()
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testSetOrganizationLogo() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/logo")!
    let imageData = Data("fake image data".utf8)

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .put: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: organization, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PUT")
      #expect(request.allHTTPHeaderFields?["Content-Type"]?.contains("multipart/form-data") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.setLogo(imageData: imageData)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testGetOrganizationRoles() async throws {
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
          ))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.getRoles(initialPage: 0, pageSize: 10)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testGetOrganizationMemberships() async throws {
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
          ))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      #expect(request.url?.query?.contains("paginated=true") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.getMemberships(initialPage: 0, pageSize: 10)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testGetOrganizationMembershipsWithQuery() async throws {
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
          ))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("query=test") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.getMemberships(query: "test", initialPage: 0, pageSize: 10)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testGetOrganizationMembershipsWithRole() async throws {
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
          ))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      let queryString = request.url?.query ?? ""
      #expect(queryString.contains("role") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.getMemberships(role: ["admin"], initialPage: 0, pageSize: 10)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAddOrganizationMember() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["user_id"] == "user123")
      #expect(request.urlEncodedFormBody!["role"] == "org:member")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.addMember(userId: "user123", role: "org:member")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testUpdateOrganizationMember() async throws {
    let organization = Organization.mock
    let membership = OrganizationMembership.mockWithUserData
    let userId = membership.publicUserData!.userId!
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships/\(userId)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["role"] == "org:admin")
      requestHandled.setValue(true)
    }
    mock.register()

    try await membership.update(role: "org:admin")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testRemoveOrganizationMember() async throws {
    let organization = Organization.mock
    let membership = OrganizationMembership.mockWithUserData
    let userId = membership.publicUserData!.userId!
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships/\(userId)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await membership.destroy()
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testGetOrganizationInvitations() async throws {
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
          ))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      #expect(request.url?.query?.contains("paginated=true") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.getInvitations(initialPage: 0, pageSize: 10)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testGetOrganizationInvitationsWithStatus() async throws {
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
          ))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("status=pending") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.getInvitations(initialPage: 0, pageSize: 10, status: "pending")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testInviteOrganizationMember() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/invitations")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationInvitation>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["email_address"] == "user@example.com")
      #expect(request.urlEncodedFormBody!["role"] == "org:member")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.inviteMember(emailAddress: "user@example.com", role: "org:member")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testCreateOrganizationDomain() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/domains")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["name"] == "example.com")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.createDomain(domainName: "example.com")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testGetOrganizationDomains() async throws {
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
          ))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.getDomains(initialPage: 0, pageSize: 10)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testGetOrganizationDomainsWithEnrollmentMode() async throws {
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
          ))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("enrollment_mode=automatic") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.getDomains(initialPage: 0, pageSize: 10, enrollmentMode: "automatic")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testGetOrganizationDomain() async throws {
    let organization = Organization.mock
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/domains/\(domain.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.getDomain(domainId: domain.id)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testGetOrganizationMembershipRequests() async throws {
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
          ))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.getMembershipRequests(initialPage: 0, pageSize: 10)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testGetOrganizationMembershipRequestsWithStatus() async throws {
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
          ))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("status=pending") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.getMembershipRequests(initialPage: 0, pageSize: 10, status: "pending")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testDeleteOrganizationDomain() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await domain.delete()
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testPrepareOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/prepare_affiliation_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["affiliation_email_address"] == "user@example.com")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await domain.prepareAffiliationVerification(affiliationEmailAddress: "user@example.com")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAttemptOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/attempt_affiliation_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await domain.attemptAffiliationVerification(code: "123456")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testRevokeOrganizationInvitation() async throws {
    let invitation = OrganizationInvitation.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(invitation.organizationId)/invitations/\(invitation.id)/revoke")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationInvitation>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await invitation.revoke()
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testDestroyOrganizationMembership() async throws {
    let membership = OrganizationMembership.mockWithUserData
    let userId = membership.publicUserData!.userId!
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(membership.organization.id)/memberships/\(userId)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await membership.destroy()
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAcceptUserOrganizationInvitation() async throws {
    let invitation = UserOrganizationInvitation.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/organization_invitations/\(invitation.id)/accept")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<UserOrganizationInvitation>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await invitation.accept()
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAcceptOrganizationSuggestion() async throws {
    let suggestion = OrganizationSuggestion.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/organization_suggestions/\(suggestion.id)/accept")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationSuggestion>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await suggestion.accept()
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAcceptOrganizationMembershipRequest() async throws {
    let request = OrganizationMembershipRequest.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(request.organizationId)/membership_requests/\(request.id)/accept")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembershipRequest>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await request.accept()
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testRejectOrganizationMembershipRequest() async throws {
    let request = OrganizationMembershipRequest.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(request.organizationId)/membership_requests/\(request.id)/reject")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembershipRequest>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await request.reject()
    #expect(requestHandled.value)
  }
}
