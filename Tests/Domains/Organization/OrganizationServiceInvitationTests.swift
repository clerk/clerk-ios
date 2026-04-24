@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct OrganizationServiceInvitationTests {
  private let sessionId = "session_test_123"

  private func makeService(baseURL: URL) -> OrganizationService {
    OrganizationService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  private nonisolated func assertSessionId(_ sessionId: String, in request: URLRequest) throws {
    let url = try #require(request.url)
    let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    let sessionQueryItem = queryItems.first { $0.name == "_clerk_session_id" }
    #expect(sessionQueryItem?.value == sessionId)
    guard sessionQueryItem?.value == sessionId else {
      throw URLError(.badURL)
    }
  }

  @Test
  func getOrganizationInvitations() async throws {
    let organization = Organization.mock
    let sessionIdValue = sessionId
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/invitations")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ClerkPaginatedResponse<OrganizationInvitation>>(
          response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      #expect(request.url?.query?.contains("paginated=true") == true)
      try assertSessionId(sessionIdValue, in: request)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationInvitations(
      organizationId: organization.id,
      offset: 0,
      pageSize: 10,
      status: nil,
      sessionId: sessionIdValue
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationInvitationsWithStatus() async throws {
    let organization = Organization.mock
    let sessionIdValue = sessionId
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/invitations")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ClerkPaginatedResponse<OrganizationInvitation>>(
          response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("status=pending") == true)
      try assertSessionId(sessionIdValue, in: request)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationInvitations(
      organizationId: organization.id,
      offset: 0,
      pageSize: 10,
      status: "pending",
      sessionId: sessionIdValue
    )
    #expect(requestHandled.value)
  }

  @Test
  func inviteOrganizationMember() async throws {
    let organization = Organization.mock
    let sessionIdValue = sessionId
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/invitations")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationInvitation>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["email_address"] == "user@example.com")
      #expect(request.urlEncodedFormBody!["role"] == "org:member")
      try assertSessionId(sessionIdValue, in: request)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).inviteOrganizationMember(
      organizationId: organization.id,
      emailAddress: "user@example.com",
      role: "org:member",
      sessionId: sessionIdValue
    )
    #expect(requestHandled.value)
  }

  @Test
  func revokeOrganizationInvitation() async throws {
    let invitation = OrganizationInvitation.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(invitation.organizationId)/invitations/\(invitation.id)/revoke")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationInvitation>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).revokeOrganizationInvitation(
      organizationId: invitation.organizationId,
      invitationId: invitation.id
    )
    #expect(requestHandled.value)
  }

  @Test
  func acceptUserOrganizationInvitation() async throws {
    let invitation = UserOrganizationInvitation.mock
    let sessionIdValue = sessionId
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/organization_invitations/\(invitation.id)/accept")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<UserOrganizationInvitation>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      try assertSessionId(sessionIdValue, in: request)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).acceptUserOrganizationInvitation(
      invitationId: invitation.id,
      sessionId: sessionIdValue
    )
    #expect(requestHandled.value)
  }

  @Test
  func acceptOrganizationSuggestion() async throws {
    let suggestion = OrganizationSuggestion.mock
    let sessionIdValue = sessionId
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/organization_suggestions/\(suggestion.id)/accept")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationSuggestion>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      try assertSessionId(sessionIdValue, in: request)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).acceptOrganizationSuggestion(
      suggestionId: suggestion.id,
      sessionId: sessionIdValue
    )
    #expect(requestHandled.value)
  }
}
