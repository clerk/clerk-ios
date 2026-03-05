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
  func signOutRejectsStaleClearWhenResponseSequenceIsOlderThanLatestAccepted() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions")!

    var latestClient = Client.mock
    latestClient.id = "latest-client"
    latestClient.updatedAt = Date(timeIntervalSince1970: 2_000_000_000)
    Clerk.shared.client = nil
    Clerk.shared.mergeClientFromResponse(latestClient, responseSequence: 10)

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
    let currentClient = try #require(Clerk.shared.client)
    #expect(currentClient.id == latestClient.id)
    #expect(currentClient.updatedAt == latestClient.updatedAt)
  }

  @Test
  func signOutWithSessionId() async throws {
    let sessionId = "sess_test123"
    let removeRequestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/remove")!
    var sessionToRemove = Session.mock
    sessionToRemove.id = sessionId
    let remainingSession = Session.mock2

    var clientWithSession = Client.mock
    clientWithSession.sessions = [sessionToRemove, remainingSession]
    clientWithSession.lastActiveSessionId = remainingSession.id
    Clerk.shared.client = clientWithSession

    var mergedClient = clientWithSession
    mergedClient.sessions = [remainingSession]

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse<Client?>(
            response: mergedClient,
            client: nil
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      removeRequestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.dependencies.sessionService.signOut(sessionId: sessionId)
    #expect(removeRequestHandled.value)
    let currentClient = try #require(Clerk.shared.client)
    #expect(currentClient != clientWithSession)
    #expect(currentClient.sessions.contains(where: { $0.id == remainingSession.id }))
    #expect(currentClient.sessions.contains(where: { $0.id == sessionToRemove.id }) == false)
  }

  @Test
  func signOutWithSessionIdClearsWhenNoSessionsRemain() async throws {
    let sessionId = "sess_test123"
    let removeRequestHandled = LockIsolated(false)
    let removeURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/remove")!
    Clerk.shared.client = .mock

    var signedOutClient = Client.mock
    signedOutClient.sessions = []
    signedOutClient.lastActiveSessionId = nil

    var removeMock = try Mock(
      url: removeURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse<Client?>(
            response: signedOutClient,
            client: nil
          )
        ),
      ]
    )

    removeMock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      removeRequestHandled.setValue(true)
    }
    removeMock.register()

    try await Clerk.shared.dependencies.sessionService.signOut(sessionId: sessionId)

    #expect(removeRequestHandled.value)
    #expect(Clerk.shared.client == nil)
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
