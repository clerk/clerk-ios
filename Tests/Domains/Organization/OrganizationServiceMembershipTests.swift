@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct OrganizationServiceMembershipTests {
  private let sessionId = "session_test_123"

  private func makeService(baseURL: URL) -> OrganizationService {
    OrganizationService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test
  func getOrganizationMemberships() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/memberships")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>(
          response: ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      #expect(request.url?.query?.contains("paginated=true") == true)
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationMemberships(
      organizationId: organization.id,
      query: nil,
      role: nil,
      offset: 0,
      pageSize: 10,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMembershipsWithQuery() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/memberships")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>(
          response: ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("query=test") == true)
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationMemberships(
      organizationId: organization.id,
      query: "test",
      role: nil,
      offset: 0,
      pageSize: 10,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationMembershipsWithRole() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/memberships")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>(
          response: ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      let queryString = request.url?.query ?? ""
      #expect(queryString.contains("role%5B%5D=admin") == true)
      #expect(queryString.contains("_clerk_session_id=\(sessionId)") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationMemberships(
      organizationId: organization.id,
      query: nil,
      role: ["admin"],
      offset: 0,
      pageSize: 10,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func addOrganizationMember() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/memberships")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      #expect(request.urlEncodedFormBody!["user_id"] == "user123")
      #expect(request.urlEncodedFormBody!["role"] == "org:member")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).addOrganizationMember(
      organizationId: organization.id,
      userId: "user123",
      role: "org:member",
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func updateOrganizationMember() async throws {
    let organization = Organization.mock
    let membership = OrganizationMembership.mockWithUserData
    let userId = try #require(membership.publicUserData?.userId)
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/memberships/\(userId)")

    try registerIsolatedStub(
      url: originalURL,
      method: .patch,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock))
    ) { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      #expect(request.urlEncodedFormBody!["role"] == "org:admin")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).updateOrganizationMember(
      organizationId: organization.id,
      userId: userId,
      role: "org:admin",
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func removeOrganizationMember() async throws {
    let organization = Organization.mock
    let membership = OrganizationMembership.mockWithUserData
    let userId = try #require(membership.publicUserData?.userId)
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/memberships/\(userId)")

    try registerIsolatedStub(
      url: originalURL,
      method: .delete,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock))
    ) { request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).removeOrganizationMember(
      organizationId: organization.id,
      userId: userId,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func destroyOrganizationMembership() async throws {
    let membership = OrganizationMembership.mockWithUserData
    let userId = try #require(membership.publicUserData?.userId)
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(membership.organization.id)/memberships/\(userId)")

    try registerIsolatedStub(
      url: originalURL,
      method: .delete,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock))
    ) { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).destroyOrganizationMembership(
      organizationId: membership.organization.id,
      userId: userId
    )
    #expect(requestHandled.value)
  }
}
