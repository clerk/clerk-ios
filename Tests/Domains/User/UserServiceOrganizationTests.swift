@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct UserServiceOrganizationTests {
  private let sessionId = "session_test_123"

  private func makeService(baseURL: URL) -> UserService {
    let apiClient = createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self)
    return UserService(apiClient: apiClient)
  }

  @Test
  func testGetOrganizationInvitations() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/organization_invitations")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ClerkPaginatedResponse<UserOrganizationInvitation>>(
          response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      #expect(request.url?.query?.contains("status=pending") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationInvitations(offset: 0, pageSize: 10, status: "pending", sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testGetOrganizationMemberships() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/organization_memberships")

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
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      #expect(request.url?.query?.contains("paginated=true") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationMemberships(offset: 0, pageSize: 10, sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testGetOrganizationSuggestions() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/organization_suggestions")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ClerkPaginatedResponse<OrganizationSuggestion>>(
          response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationSuggestions(offset: 0, pageSize: 10, status: [], sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationSuggestionsWithStatuses() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/organization_suggestions")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ClerkPaginatedResponse<OrganizationSuggestion>>(
          response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      let queryItems = request.url.flatMap {
        URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems
      }
      let statuses = queryItems?.filter { $0.name == "status" }.compactMap(\.value) ?? []
      #expect(statuses == ["pending", "accepted"])
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationSuggestions(
      offset: 0,
      pageSize: 10,
      status: ["pending", "accepted"],
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }
}
