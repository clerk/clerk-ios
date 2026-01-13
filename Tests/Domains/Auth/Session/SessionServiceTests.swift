import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct SessionServiceTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func signOut() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.dependencies.sessionService.signOut(sessionId: nil)
    #expect(requestHandled.value)
  }

  @Test
  func signOutWithSessionId() async throws {
    let sessionId = "sess_test123"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/remove")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.dependencies.sessionService.signOut(sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func setActive() async throws {
    let sessionId = "sess_test123"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/touch")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody
      if let body {
        #expect(body["active_organization_id"] == "")
      }
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.dependencies.sessionService.setActive(sessionId: sessionId, organizationId: nil)
    #expect(requestHandled.value)
  }

  @Test
  func setActiveWithOrganizationId() async throws {
    let sessionId = "sess_test123"
    let organizationId = "org_test456"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/touch")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody
      if let body {
        #expect(body["active_organization_id"] == organizationId)
      }
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.dependencies.sessionService.setActive(
      sessionId: sessionId,
      organizationId: organizationId
    )
    #expect(requestHandled.value)
  }

  @Test
  func testRevoke() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/sessions/\(session.id)/revoke")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: session, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.sessionService.revoke(sessionId: session.id)
    #expect(requestHandled.value)
  }
}
