@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct EnvironmentServiceTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func testGet() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/environment")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.environmentService.get()
    #expect(requestHandled.value)
  }

  @Test
  func testGetReturnsEnvironment() async throws {
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/environment")!

    let mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock),
      ]
    )
    mock.register()

    let environment = try await Clerk.shared.dependencies.environmentService.get()
    #expect(environment.authConfig.singleSessionMode == Clerk.Environment.mock.authConfig.singleSessionMode)
  }

  @Test
  func testGetHandlesNetworkError() async throws {
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/environment")!

    let errorData = try JSONEncoder.clerkEncoder.encode(
      ClerkErrorResponse(
        errors: [
          ClerkAPIError(code: "network_error", message: "Network error", longMessage: nil)
        ],
        clerkTraceId: "trace123"
      )
    )

    let mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 500,
      data: [
        .get: errorData,
      ]
    )
    mock.register()

    do {
      _ = try await Clerk.shared.dependencies.environmentService.get()
      #expect(Bool(false), "Should have thrown an error")
    } catch {
      // Expected to throw
      #expect(error is ClerkAPIError)
    }
  }

  @Test
  func testGetUsesCorrectEndpoint() async throws {
    let requestHandled = LockIsolated(false)
    let capturedPath = LockIsolated<String?>(nil)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/environment")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      requestHandled.setValue(true)
      capturedPath.setValue(request.url?.path)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.environmentService.get()
    #expect(requestHandled.value)
    #expect(capturedPath.value == "/v1/environment")
  }
}