@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct SessionServiceTests {
  private let actingSessionId = "acting_session_test_123"

  private func makeService(baseURL: URL) -> SessionService {
    SessionService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test
  func signOut() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sessions")

    try registerIsolatedStub(
      url: originalURL,
      method: .delete,
      data: JSONEncoder.clerkEncoder.encode(EmptyResponse())
    ) { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    try await makeService(baseURL: baseURL).signOut(sessionId: nil)
    #expect(requestHandled.value)
  }

  @Test
  func signOutWithSessionId() async throws {
    let sessionId = "sess_test123"
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sessions/\(sessionId)/remove")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(EmptyResponse())
    ) { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    try await makeService(baseURL: baseURL).signOut(sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func setActive() async throws {
    let sessionId = "sess_test123"
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sessions/\(sessionId)/touch")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(EmptyResponse())
    ) { request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody
      if let body {
        #expect(body["active_organization_id"] == "")
      }
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    try await makeService(baseURL: baseURL).setActive(sessionId: sessionId, organizationId: nil)
    #expect(requestHandled.value)
  }

  @Test
  func setActiveWithOrganizationId() async throws {
    let sessionId = "sess_test123"
    let organizationId = "org_test456"
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sessions/\(sessionId)/touch")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(EmptyResponse())
    ) { request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody
      if let body {
        #expect(body["active_organization_id"] == organizationId)
      }
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    try await makeService(baseURL: baseURL).setActive(
      sessionId: sessionId,
      organizationId: organizationId
    )
    #expect(requestHandled.value)
  }

  @Test
  func fetchToken() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sessions/\(session.id)/tokens")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(TokenResource.mock)
    ) { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).fetchToken(sessionId: session.id, template: nil)
    #expect(requestHandled.value)
  }

  @Test
  func fetchTokenWithTemplate() async throws {
    let session = Session.mock
    let template = "firebase"
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sessions/\(session.id)/tokens/\(template)")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(TokenResource.mock)
    ) { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).fetchToken(sessionId: session.id, template: template)
    #expect(requestHandled.value)
  }

  @Test
  func testRevoke() async throws {
    let session = Session.mock
    let actingSessionIdValue = actingSessionId
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/sessions/\(session.id)/revoke")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: session, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      let url = try #require(request.url)
      let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
      let actingSessionQueryItem = queryItems.first { $0.name == "_clerk_session_id" }
      #expect(actingSessionQueryItem?.value == actingSessionIdValue)
      guard actingSessionQueryItem?.value == actingSessionIdValue else {
        throw URLError(.badURL)
      }
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).revoke(sessionId: session.id, actingSessionId: actingSessionIdValue)
    #expect(requestHandled.value)
  }
}
