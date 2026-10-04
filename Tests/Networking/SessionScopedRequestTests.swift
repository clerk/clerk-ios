//
//  SessionScopedRequestTests.swift
//  Clerk
//

@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct SessionScopedRequestTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func userRequestCarriesTheActiveSessionId() async throws {
    Clerk.shared.client = .mock
    let activeSessionId = try #require(Clerk.shared.session?.id)
    let requestHandled = LockIsolated(false)
    let meURL = URL(string: mockBaseUrl.absoluteString + "/v1/me")!

    var mock = try Mock(
      url: meURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClientResponse<User>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.url?.queryParam(named: "_clerk_session_id") == activeSessionId)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(UserAPI.reload())
    #expect(requestHandled.value)
  }

  @Test
  func userRequestWithoutAnActiveSessionSendsNoSessionId() async throws {
    Clerk.shared.client = .mockSignedOut
    let requestHandled = LockIsolated(false)
    let meURL = URL(string: mockBaseUrl.absoluteString + "/v1/me")!

    var mock = try Mock(
      url: meURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClientResponse<User>(response: .mock, client: .mockSignedOut)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.url?.queryParam(named: "_clerk_session_id") == nil)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(UserAPI.reload())
    #expect(requestHandled.value)
  }

  @Test
  func sessionScopedRequestCarriesTheActiveSessionId() async throws {
    Clerk.shared.client = .mock
    let activeSessionId = try #require(Clerk.shared.session?.id)
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder().encode(["success": true]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.url?.queryParam(named: "_clerk_session_id") == activeSessionId)
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(path: "/v1/test", method: .get, scopedToActiveSession: true)
    _ = try await Clerk.shared.dependencies.apiClient.send(request)
    #expect(requestHandled.value)
  }

  @Test
  func requestOutsideSessionScopeSendsNoSessionId() async throws {
    Clerk.shared.client = .mock
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder().encode(["success": true]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.url?.query?.contains("_clerk_session_id") != true)
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(path: "/v1/test", method: .get)
    _ = try await Clerk.shared.dependencies.apiClient.send(request)
    #expect(requestHandled.value)
  }

  @Test(arguments: [true, false], ["1", "2"])
  func retriesRespectActiveSessionChanges(scopedToActiveSession: Bool, nextSessionID: String) async throws {
    let clerk = Clerk.shared
    let deviceToken = "test-device-token"
    clerk.identityController.resetRuntimeIdentity()
    try clerk.seedIdentity(deviceToken: deviceToken, client: .mock)
    let originalGeneration = clerk.clientResponseGeneration
    try #require(clerk.session?.id == "1")

    var switchedClient = Client.mock
    switchedClient.lastActiveSessionId = nextSessionID
    let nextSession = try #require(switchedClient.sessions.first { $0.id == nextSessionID })
    let touchURL = try #require(URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(nextSessionID)/touch"))
    let touchMock = try Mock(
      url: touchURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [.post: JSONEncoder.clerkEncoder.encode(ClientResponse(response: nextSession, client: switchedClient))]
    )
    touchMock.register()

    let sessionsSent = LockIsolated<[String?]>([])
    let meURL = try #require(URL(string: mockBaseUrl.absoluteString + "/v1/me"))
    var throttledMock = Mock(
      url: meURL, ignoreQuery: true, contentType: .json, statusCode: 429,
      data: [.patch: Data(#"{"errors":[{"code":"rate_limit_exceeded","message":"Too many requests"}]}"#.utf8)]
    )
    throttledMock.onRequestHandler = OnRequestHandler { @Sendable request in
      sessionsSent.withValue { $0.append(request.url?.queryParam(named: "_clerk_session_id")) }
    }
    throttledMock.register()

    let auth = clerk.auth
    let retry = ClerkRateLimitRetryMiddleware(sleep: { _ in
      do {
        try await auth.setActive(sessionId: nextSessionID, organizationId: nil)
      } catch {
        Issue.record("Could not set the active session: \(error)")
      }
      await MainActor.run {
        #expect(clerk.session?.id == nextSessionID)
        #expect(clerk.identityController.currentDeviceToken == deviceToken)
        #expect(clerk.client?.id == Client.mock.id)
        #expect(clerk.clientResponseGeneration == originalGeneration)
      }
    })
    let pipeline = NetworkingPipeline(
      requestMiddleware: [ClerkHeaderRequestMiddleware(runtimeScope: clerk.runtimeScope)],
      responseMiddleware: [ClerkErrorThrowingResponseMiddleware()],
      retryMiddleware: [retry]
    )
    let apiClient = APIClient(baseURL: mockBaseUrl, runtimeScope: clerk.runtimeScope) { configuration in
      configuration.pipeline = pipeline
      configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
    }

    let shouldCancelRetry = scopedToActiveSession && nextSessionID != "1"
    await #expect {
      _ = try await apiClient.send(Request<EmptyResponse>(
        path: "/v1/me",
        method: .patch,
        scopedToActiveSession: scopedToActiveSession,
        body: ["first_name": "Updated"]
      ))
    } throws: { error in
      if shouldCancelRetry {
        if case APIClientError.identityChangedBeforeRetry = error {
          return true
        }
        return false
      }
      return (error as? ClerkAPIError)?.code == "rate_limit_exceeded"
    }

    let originalSessionID: String? = scopedToActiveSession ? "1" : nil
    let expectedSessions = Array(repeating: originalSessionID, count: shouldCancelRetry ? 1 : 2)
    #expect(sessionsSent.value == expectedSessions)
  }
}
