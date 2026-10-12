@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkInvalidAuthResponseMiddlewareTests {
  @Test
  func coalescesConcurrentInvalidAuthRefreshes() async {
    let refreshCount = LockIsolated(0)
    let clerk = Clerk()

    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      transport: FakeTransport.answeringClient {
        refreshCount.withValue { $0 += 1 }
        try await Task.sleep(for: .milliseconds(100))
        return Client.mock
      }
    )

    async let first: Void = clerk.runtime.refreshClientAfterInvalidAuth()
    async let second: Void = clerk.runtime.refreshClientAfterInvalidAuth()
    _ = await (first, second)

    #expect(refreshCount.withValue { $0 } == 1)
  }

  @Test(arguments: ["authentication_invalid", "resource_not_found", "signed_out"])
  func invalidAuthResponseRefreshesTheClient(code: String) async throws {
    let refreshCount = LockIsolated(0)
    let clerk = try clerkRefreshingToSignedOut(refreshCount: refreshCount)
    let middleware = ClerkInvalidAuthResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    try await middleware.validate(
      response(statusCode: 401, path: "/v1/client/sessions/1/tokens"),
      data: errorBody(code: code),
      for: request(method: "POST", path: "/v1/client/sessions/1/tokens")
    )

    #expect(refreshCount.value == 1)
    #expect(clerk.session == nil)
  }

  @Test
  func otherErrorsDoNotRefreshTheClient() async throws {
    let refreshCount = LockIsolated(0)
    let clerk = try clerkRefreshingToSignedOut(refreshCount: refreshCount)
    let middleware = ClerkInvalidAuthResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    try await middleware.validate(
      response(statusCode: 422, path: "/v1/client/sign_ins"),
      data: errorBody(code: "form_password_incorrect"),
      for: request(method: "POST", path: "/v1/client/sign_ins")
    )

    #expect(refreshCount.value == 0)
    #expect(clerk.session != nil)
  }

  @Test
  func signedOutClientFetchDoesNotRefreshAgain() async throws {
    let refreshCount = LockIsolated(0)
    let clerk = try clerkRefreshingToSignedOut(refreshCount: refreshCount)
    let middleware = ClerkInvalidAuthResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    try await middleware.validate(
      response(statusCode: 401, path: "/v1/client"),
      data: errorBody(code: "signed_out"),
      for: request(method: "GET", path: "/v1/client")
    )

    #expect(refreshCount.value == 0)
  }

  private func clerkRefreshingToSignedOut(refreshCount: LockIsolated<Int>) throws -> Clerk {
    configureClerkForTesting()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      transport: FakeTransport.answeringClient {
        refreshCount.withValue { $0 += 1 }
        return Client.mockSignedOut
      }
    )
    clerk.client = Client.mock
    try #require(clerk.session != nil)
    return clerk
  }

  private func request(method: String, path: String) throws -> URLRequest {
    var request = try URLRequest(url: #require(URL(string: "https://example.com\(path)")))
    request.httpMethod = method
    return request
  }

  private func response(statusCode: Int, path: String) throws -> HTTPURLResponse {
    let url = try #require(URL(string: "https://example.com\(path)"))
    return try #require(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil))
  }

  private func errorBody(code: String) -> Data {
    Data(#"{"errors":[{"code":"\#(code)","message":"Error"}]}"#.utf8)
  }
}
