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

    _ = try await Clerk.shared.dependencies.userService.reload()
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

    _ = try await Clerk.shared.dependencies.userService.reload()
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
      #expect(request.url?.query?.contains("_clerk_session_id") == false)
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(path: "/v1/test", method: .get)
    _ = try await Clerk.shared.dependencies.apiClient.send(request)
    #expect(requestHandled.value)
  }
}
