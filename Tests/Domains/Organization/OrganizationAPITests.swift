@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct OrganizationAPITests {
  init() {
    configureClerkForTesting()
  }

  enum DomainMutationAPIErrorScenario: CaseIterable {
    case create
    case delete
    case prepareAffiliationVerification
    case attemptAffiliationVerification
    case updateEnrollmentMode

    var method: Mock.HTTPMethod {
      switch self {
      case .delete:
        .delete
      case .create, .prepareAffiliationVerification, .attemptAffiliationVerification, .updateEnrollmentMode:
        .post
      }
    }

    func path(domain: OrganizationDomain) -> String {
      switch self {
      case .create:
        "/v1/organizations/\(domain.organizationId)/domains"
      case .delete:
        "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)"
      case .prepareAffiliationVerification:
        "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/prepare_affiliation_verification"
      case .attemptAffiliationVerification:
        "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/attempt_affiliation_verification"
      case .updateEnrollmentMode:
        "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/update_enrollment_mode"
      }
    }

    @MainActor
    func perform(domain: OrganizationDomain) async throws {
      switch self {
      case .create:
        _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.createDomain(
          organizationId: domain.organizationId,
          domainName: "invalid domain"
        )).value.response
      case .delete:
        _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.deleteDomain(
          organizationId: domain.organizationId,
          domainId: domain.id
        )).value.response
      case .prepareAffiliationVerification:
        _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.prepareDomainAffiliationVerification(
          organizationId: domain.organizationId,
          domainId: domain.id,
          affiliationEmailAddress: "invalid-email"
        )).value.response
      case .attemptAffiliationVerification:
        _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.attemptDomainAffiliationVerification(
          organizationId: domain.organizationId,
          domainId: domain.id,
          code: "000000"
        )).value.response
      case .updateEnrollmentMode:
        _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.updateDomainEnrollmentMode(
          organizationId: domain.organizationId,
          domainId: domain.id,
          enrollmentMode: "invalid_mode",
          deletePending: nil
        )).value.response
      }
    }
  }

  @Test
  func createOrganization() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["name"] == "My Org")
      #expect(request.urlEncodedFormBody!["slug"] == nil)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.create(name: "My Org", slug: nil)).value.response
    #expect(requestHandled.value)
  }

  @Test
  func createOrganizationIncludesSlugWhenProvided() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["name"] == "My Org")
      #expect(request.urlEncodedFormBody!["slug"] == "my-org")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.create(name: "My Org", slug: "my-org")).value.response
    #expect(requestHandled.value)
  }

  @Test
  func getOrganization() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: organization, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.get(organizationId: organization.id)).value.response
    #expect(requestHandled.value)
  }

  @Test
  func updateOrganization() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: organization, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["name"] == "New Name")
      #expect(request.urlEncodedFormBody!["slug"] == "new-slug")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.update(
      organizationId: organization.id,
      name: "New Name",
      slug: "new-slug"
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func updateOrganizationOmitsSlugWhenNil() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: organization, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["name"] == "New Name")
      #expect(request.urlEncodedFormBody!["slug"] == nil)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.update(
      organizationId: organization.id,
      name: "New Name",
      slug: nil
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func updateOrganizationPropagatesAPIErrors() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 422,
      data: [
        .patch: JSONEncoder.clerkEncoder.encode(
          ClerkErrorResponse(
            errors: [
              ClerkAPIError(
                code: "form_param_format_invalid",
                message: "Slug is invalid",
                longMessage: nil,
                meta: nil,
                clerkTraceId: nil
              ),
            ],
            clerkTraceId: nil
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "PATCH")
      requestHandled.setValue(true)
    }
    mock.register()

    do {
      _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.update(
        organizationId: organization.id,
        name: "New Name",
        slug: "invalid slug"
      )).value.response
      #expect(Bool(false), "Expected API error to be thrown")
    } catch let error as ClerkAPIError {
      #expect(requestHandled.value)
      #expect(error.code == "form_param_format_invalid")
      #expect(error.message == "Slug is invalid")
    } catch {
      #expect(Bool(false), "Expected ClerkAPIError, got \(error)")
    }
  }

  @Test
  func destroyOrganization() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.destroy(organizationId: organization.id)).value.response
    #expect(requestHandled.value)
  }

  @Test
  func setOrganizationLogo() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/logo")!
    let imageData = Data("fake image data".utf8)

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .put: JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: organization, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "PUT")
      #expect(request.allHTTPHeaderFields?["Content-Type"]?.contains("multipart/form-data") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await organization.setLogo(imageData: imageData)
    #expect(requestHandled.value)
  }

  @Test
  func deleteOrganizationLogo() async throws {
    let organization = Organization.mock
    let deletedObject = DeletedObject(object: "image", id: "logo_id", deleted: true)
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/logo")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: deletedObject, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    let response = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.deleteLogo(
      organizationId: organization.id
    )).value.response
    #expect(requestHandled.value)
    #expect(response.object == deletedObject.object)
    #expect(response.id == deletedObject.id)
    #expect(response.deleted == deletedObject.deleted)
  }

  @Test
  func getOrganizationRoles() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/roles")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<RoleResource>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1, hasRoleSetMigration: true),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    let response = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.getRoles(
      organizationId: organization.id,
      offset: 0,
      pageSize: 10
    )).value.response
    #expect(response.hasRoleSetMigration == true)
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMemberships() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>(
            response: ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      #expect(request.url?.query?.contains("paginated=true") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.getMemberships(
      organizationId: organization.id,
      query: nil,
      role: nil,
      offset: 0,
      pageSize: 10
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMembershipsWithQuery() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>(
            response: ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("query=test") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.getMemberships(
      organizationId: organization.id,
      query: "test",
      role: nil,
      offset: 0,
      pageSize: 10
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMembershipsWithRole() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>(
            response: ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      let queryString = request.url?.query ?? ""
      #expect(queryString.contains("role") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.getMemberships(
      organizationId: organization.id,
      query: nil,
      role: ["admin"],
      offset: 0,
      pageSize: 10
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func addOrganizationMember() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["user_id"] == "user123")
      #expect(request.urlEncodedFormBody!["role"] == "org:member")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.addMember(
      organizationId: organization.id,
      userId: "user123",
      role: "org:member"
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func updateOrganizationMember() async throws {
    let organization = Organization.mock
    let membership = OrganizationMembership.mockWithUserData
    let userId = try #require(membership.publicUserData?.userId)
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships/\(userId)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["role"] == "org:admin")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.updateMember(
      organizationId: organization.id,
      userId: userId,
      role: "org:admin"
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func removeOrganizationMember() async throws {
    let organization = Organization.mock
    let membership = OrganizationMembership.mockWithUserData
    let userId = try #require(membership.publicUserData?.userId)
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/memberships/\(userId)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.removeMember(
      organizationId: organization.id,
      userId: userId
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationInvitations() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/invitations")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationInvitation>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      #expect(request.url?.query?.contains("paginated") == false)
      let queryItems = request.url.flatMap {
        URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems
      }
      let statuses = queryItems?.filter { $0.name == "status" }.compactMap(\.value) ?? []
      #expect(statuses.isEmpty)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.getInvitations(
      organizationId: organization.id,
      offset: 0,
      pageSize: 10,
      status: []
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationInvitationsWithStatuses() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/invitations")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationInvitation>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      let queryItems = request.url.flatMap {
        URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems
      }
      let statuses = queryItems?.filter { $0.name == "status" }.compactMap(\.value) ?? []
      #expect(statuses == ["pending", "accepted"])
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.getInvitations(
      organizationId: organization.id,
      offset: 0,
      pageSize: 10,
      status: ["pending", "accepted"]
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func inviteOrganizationMember() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/invitations")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationInvitation>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["email_address"] == "user@example.com")
      #expect(request.urlEncodedFormBody!["role"] == "org:member")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.inviteMember(
      organizationId: organization.id,
      emailAddress: "user@example.com",
      role: "org:member"
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func inviteOrganizationMembers() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/invitations/bulk")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<[OrganizationInvitation]>(response: [.mock], client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      #expect(request.urlEncodedFormBodyMultiValue!["email_address"] == ["one@example.com", "two@example.com"])
      #expect(request.urlEncodedFormBody!["role"] == "org:member")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.inviteMembers(
      organizationId: organization.id,
      emailAddresses: ["one@example.com", "two@example.com"],
      role: "org:member"
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func createOrganizationDomain() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/domains")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["name"] == "example.com")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.createDomain(
      organizationId: organization.id,
      domainName: "example.com"
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationDomains() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/domains")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationDomain>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.getDomains(
      organizationId: organization.id,
      offset: 0,
      pageSize: 10,
      enrollmentMode: nil
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationDomainsWithEnrollmentMode() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/domains")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationDomain>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("enrollment_mode=automatic") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.getDomains(
      organizationId: organization.id,
      offset: 0,
      pageSize: 10,
      enrollmentMode: "automatic"
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationDomain() async throws {
    let organization = Organization.mock
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/domains/\(domain.id)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.getDomain(
      organizationId: organization.id,
      domainId: domain.id
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMembershipRequests() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/membership_requests")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationMembershipRequest>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.getMembershipRequests(
      organizationId: organization.id,
      offset: 0,
      pageSize: 10,
      status: nil
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMembershipRequestsWithStatus() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/membership_requests")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationMembershipRequest>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("status=pending") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.getMembershipRequests(
      organizationId: organization.id,
      offset: 0,
      pageSize: 10,
      status: "pending"
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func deleteOrganizationDomain() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.deleteDomain(
      organizationId: domain.organizationId,
      domainId: domain.id
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func prepareOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/prepare_affiliation_verification")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      #expect(request.urlEncodedFormBody!["affiliation_email_address"] == "user@example.com")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.prepareDomainAffiliationVerification(
      organizationId: domain.organizationId,
      domainId: domain.id,
      affiliationEmailAddress: "user@example.com"
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func attemptOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/attempt_affiliation_verification")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.attemptDomainAffiliationVerification(
      organizationId: domain.organizationId,
      domainId: domain.id,
      code: "123456"
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func updateOrganizationDomainEnrollmentMode() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/update_enrollment_mode")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      #expect(request.urlEncodedFormBody!["enrollment_mode"] == "automatic_invitation")
      #expect(request.urlEncodedFormBody!["delete_pending"] == "1")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.updateDomainEnrollmentMode(
      organizationId: domain.organizationId,
      domainId: domain.id,
      enrollmentMode: "automatic_invitation",
      deletePending: true
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func updateOrganizationDomainEnrollmentModeOmitsDeletePendingWhenNil() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/update_enrollment_mode")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      #expect(request.urlEncodedFormBody!["enrollment_mode"] == "manual_invitation")
      #expect(request.urlEncodedFormBody!["delete_pending"] == nil)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.updateDomainEnrollmentMode(
      organizationId: domain.organizationId,
      domainId: domain.id,
      enrollmentMode: "manual_invitation",
      deletePending: nil
    )).value.response
    #expect(requestHandled.value)
  }

  @Test(arguments: DomainMutationAPIErrorScenario.allCases)
  func organizationDomainMutationsPropagateAPIErrors(
    scenario: DomainMutationAPIErrorScenario
  ) async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + scenario.path(domain: domain))!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 422,
      data: [
        scenario.method: JSONEncoder.clerkEncoder.encode(
          ClerkErrorResponse(
            errors: [
              ClerkAPIError(
                code: "form_param_format_invalid",
                message: "Domain request is invalid",
                longMessage: nil,
                meta: JSON.object(["param_name": .string("domain")]),
                clerkTraceId: "trace_domain_error"
              ),
            ],
            clerkTraceId: "trace_domain_error"
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == scenario.method.rawValue)
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    do {
      try await scenario.perform(domain: domain)
      #expect(Bool(false), "Expected API error to be thrown")
    } catch let error as ClerkAPIError {
      #expect(requestHandled.value)
      #expect(error.code == "form_param_format_invalid")
      #expect(error.message == "Domain request is invalid")
      #expect(error.context?["paramName"] == "domain")
      #expect(error.context?["traceId"] == "trace_domain_error")
    } catch {
      #expect(Bool(false), "Expected ClerkAPIError, got \(error)")
    }
  }

  @Test
  func revokeOrganizationInvitation() async throws {
    let invitation = OrganizationInvitation.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(invitation.organizationId)/invitations/\(invitation.id)/revoke")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationInvitation>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.revokeInvitation(
      organizationId: invitation.organizationId,
      invitationId: invitation.id
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func destroyOrganizationMembership() async throws {
    let membership = OrganizationMembership.mockWithUserData
    let userId = try #require(membership.publicUserData?.userId)
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(membership.organization.id)/memberships/\(userId)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await membership.destroy()
    #expect(requestHandled.value)
  }

  @Test
  func acceptUserOrganizationInvitation() async throws {
    let invitation = UserOrganizationInvitation.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/organization_invitations/\(invitation.id)/accept")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<UserOrganizationInvitation>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.acceptUserInvitation(
      invitationId: invitation.id
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func acceptOrganizationSuggestion() async throws {
    let suggestion = OrganizationSuggestion.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/organization_suggestions/\(suggestion.id)/accept")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationSuggestion>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.acceptSuggestion(
      suggestionId: suggestion.id
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func acceptOrganizationMembershipRequest() async throws {
    let request = OrganizationMembershipRequest.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(request.organizationId)/membership_requests/\(request.id)/accept")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembershipRequest>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.acceptMembershipRequest(
      organizationId: request.organizationId,
      requestId: request.id
    )).value.response
    #expect(requestHandled.value)
  }

  @Test
  func rejectOrganizationMembershipRequest() async throws {
    let request = OrganizationMembershipRequest.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(request.organizationId)/membership_requests/\(request.id)/reject")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembershipRequest>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(OrganizationAPI.rejectMembershipRequest(
      organizationId: request.organizationId,
      requestId: request.id
    )).value.response
    #expect(requestHandled.value)
  }
}
