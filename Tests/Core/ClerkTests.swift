import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct ClerkTests {

  init() {
    configureClerkForTesting()
  }

  @Test
  func testSignOut() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(EmptyResponse())
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.signOut()
    #expect(requestHandled.value)
  }

  @Test
  func testSignOutWithSessionId() async throws {
    let sessionId = "sess_test123"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/remove")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(EmptyResponse())
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.signOut(sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testSetActive() async throws {
    let sessionId = "sess_test123"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/touch")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(EmptyResponse())
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody
      if let body = body {
        #expect(body["active_organization_id"] == "")
      }
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.setActive(sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testSetActiveWithOrganizationId() async throws {
    let sessionId = "sess_test123"
    let organizationId = "org_test456"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/touch")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(EmptyResponse())
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody
      if let body = body {
        #expect(body["active_organization_id"] == organizationId)
      }
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.setActive(sessionId: sessionId, organizationId: organizationId)
    #expect(requestHandled.value)
  }
}
