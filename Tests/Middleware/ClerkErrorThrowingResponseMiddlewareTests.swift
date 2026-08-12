@testable import ClerkKit
import Foundation
import Testing

@MainActor
struct ClerkErrorThrowingResponseMiddlewareTests {
  @Test
  func unsupportedAppVersionUpdatesStatusBeforeThrowing() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let request = try makeRequest(path: "/v1/client", sequence: 1)
    let response = try makeResponse(for: request, statusCode: 403)

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(response, data: unsupportedPayload, for: request)
    }

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0.0")
  }

  @Test
  func environmentRefreshDoesNotClearServerEnforcedStatus() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let request = try makeRequest(path: "/v1/client", sequence: 1)
    let response = try makeResponse(for: request, statusCode: 403)

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(response, data: unsupportedPayload, for: request)
    }

    clerk.environment = .mock

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0.0")
  }

  @Test
  func successfulProtectedResponseClearsServerEnforcedStatus() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let unsupportedRequest = try makeRequest(path: "/v1/client", sequence: 1)
    let unsupportedResponse = try makeResponse(for: unsupportedRequest, statusCode: 403)

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(unsupportedResponse, data: unsupportedPayload, for: unsupportedRequest)
    }

    clerk.environment = .mock
    let successfulRequest = try makeRequest(path: "/v1/client", sequence: 2)
    let successfulResponse = try makeResponse(for: successfulRequest, statusCode: 200)
    try await middleware.validate(successfulResponse, data: Data(), for: successfulRequest)

    #expect(clerk.appVersionSupportStatus == .supportedDefault)
  }

  @Test
  func successfulEnvironmentResponseDoesNotClearServerEnforcedStatus() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let unsupportedRequest = try makeRequest(path: "/v1/client", sequence: 1)
    let unsupportedResponse = try makeResponse(for: unsupportedRequest, statusCode: 403)

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(unsupportedResponse, data: unsupportedPayload, for: unsupportedRequest)
    }

    let environmentRequest = try makeRequest(path: "/v1/environment", sequence: 2)
    let environmentResponse = try makeResponse(for: environmentRequest, statusCode: 200)
    try await middleware.validate(environmentResponse, data: Data(), for: environmentRequest)

    #expect(!clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func olderProtectedSuccessDoesNotClearNewerServerEnforcedStatus() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let unsupportedRequest = try makeRequest(path: "/v1/client", sequence: 2)
    let unsupportedResponse = try makeResponse(for: unsupportedRequest, statusCode: 403)

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(unsupportedResponse, data: unsupportedPayload, for: unsupportedRequest)
    }

    let olderRequest = try makeRequest(path: "/v1/client/sessions", sequence: 1)
    let olderResponse = try makeResponse(for: olderRequest, statusCode: 200)
    try await middleware.validate(olderResponse, data: Data(), for: olderRequest)

    #expect(!clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func olderUnsupportedResponseDoesNotOverrideNewerProtectedSuccess() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let successfulRequest = try makeRequest(path: "/v1/client/sessions", sequence: 2)
    let successfulResponse = try makeResponse(for: successfulRequest, statusCode: 200)
    try await middleware.validate(successfulResponse, data: Data(), for: successfulRequest)

    let olderRequest = try makeRequest(path: "/v1/client", sequence: 1)
    let olderResponse = try makeResponse(for: olderRequest, statusCode: 403)
    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(olderResponse, data: unsupportedPayload, for: olderRequest)
    }

    #expect(clerk.appVersionSupportStatus.isSupported)
  }

  private var unsupportedPayload: Data {
    Data(
      """
      {
        "errors": [{
          "code": "unsupported_app_version",
          "message": "Unsupported app version",
          "meta": {
            "platform": "ios",
            "app_identifier": "\(DeviceHelper.bundleID)",
            "current_version": "1.0.0",
            "minimum_version": "2.0.0",
            "update_url": "https://apps.apple.com/app/id123"
          }
        }]
      }
      """.utf8
    )
  }

  private func makeMiddleware(for clerk: Clerk) -> ClerkErrorThrowingResponseMiddleware {
    ClerkErrorThrowingResponseMiddleware(
      runtimeScope: .current { clerk },
      logNetworkError: { _, _, _ in }
    )
  }

  private func makeRequest(path: String, sequence: Int) throws -> URLRequest {
    let url = try #require(URL(string: "https://example.com\(path)"))
    var request = URLRequest(url: url)
    request.setClerkRequestSequence(sequence)
    return request
  }

  private func makeResponse(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
    let url = try #require(request.url)
    return try #require(
      HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
    )
  }
}
