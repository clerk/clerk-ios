@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct OrganizationServiceDomainAndRequestTests {
  private let sessionId = "session_test_123"

  private func makeService(baseURL: URL) -> OrganizationService {
    OrganizationService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test
  func createOrganizationDomain() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/domains")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["name"] == "example.com")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).createOrganizationDomain(
      organizationId: organization.id,
      domainName: "example.com",
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationDomains() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/domains")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ClerkPaginatedResponse<OrganizationDomain>>(
          response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationDomains(
      organizationId: organization.id,
      initialPage: 0,
      pageSize: 10,
      enrollmentMode: nil,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationDomainsWithEnrollmentMode() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/domains")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ClerkPaginatedResponse<OrganizationDomain>>(
          response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("enrollment_mode=automatic") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationDomains(
      organizationId: organization.id,
      initialPage: 0,
      pageSize: 10,
      enrollmentMode: "automatic",
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationDomain() async throws {
    let organization = Organization.mock
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/domains/\(domain.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationDomain(
      organizationId: organization.id,
      domainId: domain.id,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMembershipRequests() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/membership_requests")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ClerkPaginatedResponse<OrganizationMembershipRequest>>(
          response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationMembershipRequests(
      organizationId: organization.id,
      initialPage: 0,
      pageSize: 10,
      status: nil,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMembershipRequestsWithStatus() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/membership_requests")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ClerkPaginatedResponse<OrganizationMembershipRequest>>(
          response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("status=pending") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationMembershipRequests(
      organizationId: organization.id,
      initialPage: 0,
      pageSize: 10,
      status: "pending",
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func deleteOrganizationDomain() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(domain.organizationId)/domains/\(domain.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .delete,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).deleteOrganizationDomain(
      organizationId: domain.organizationId,
      domainId: domain.id,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func prepareOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(domain.organizationId)/domains/\(domain.id)/prepare_affiliation_verification")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["affiliation_email_address"] == "user@example.com")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).prepareOrganizationDomainAffiliationVerification(
      organizationId: domain.organizationId,
      domainId: domain.id,
      affiliationEmailAddress: "user@example.com",
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(domain.organizationId)/domains/\(domain.id)/attempt_affiliation_verification")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptOrganizationDomainAffiliationVerification(
      organizationId: domain.organizationId,
      domainId: domain.id,
      code: "123456",
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func acceptOrganizationMembershipRequest() async throws {
    let request = OrganizationMembershipRequest.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(request.organizationId)/membership_requests/\(request.id)/accept")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembershipRequest>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).acceptOrganizationMembershipRequest(
      organizationId: request.organizationId,
      requestId: request.id,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func rejectOrganizationMembershipRequest() async throws {
    let request = OrganizationMembershipRequest.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(request.organizationId)/membership_requests/\(request.id)/reject")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembershipRequest>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).rejectOrganizationMembershipRequest(
      organizationId: request.organizationId,
      requestId: request.id,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }
}
