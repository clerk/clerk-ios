@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

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
    Clerk.shared.client = .mock

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.dependencies.sessionService.signOut(sessionId: nil)
    #expect(requestHandled.value)
    #expect(Clerk.shared.client == nil)
  }

  @Test
  func signOutWithSessionId() async throws {
    let sessionId = "sess_test123"
    let removeRequestHandled = LockIsolated(false)
    let refreshRequestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/remove")!
    let refreshURL = URL(string: mockBaseUrl.absoluteString + "/v1/client")!
    Clerk.shared.client = .mock

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      removeRequestHandled.setValue(true)
    }
    mock.register()

    var refreshMock = try Mock(
      url: refreshURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClientResponse<Client?>(response: .mock, client: .mock)),
      ]
    )

    refreshMock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      refreshRequestHandled.setValue(true)
    }
    refreshMock.register()

    try await Clerk.shared.dependencies.sessionService.signOut(sessionId: sessionId)
    #expect(removeRequestHandled.value)
    #expect(refreshRequestHandled.value)
    #expect(Clerk.shared.client?.id == Client.mock.id)
  }

  @Test
  func setActive() async throws {
    let sessionId = "sess_test123"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/touch")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(EmptyResponse()),
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

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(EmptyResponse()),
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
  func fetchToken() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/tokens")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(TokenResource.mock),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(sessionId: session.id, template: nil)
    #expect(requestHandled.value)
  }

  @Test
  func fetchTokenWithTemplate() async throws {
    let session = Session.mock
    let template = "firebase"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/tokens/\(template)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(TokenResource.mock),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(sessionId: session.id, template: template)
    #expect(requestHandled.value)
  }

  @Test
  func testRevoke() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/sessions/\(session.id)/revoke")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: session, client: .mock)),
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
