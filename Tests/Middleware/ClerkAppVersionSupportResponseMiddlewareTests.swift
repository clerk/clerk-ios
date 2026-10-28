@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkAppVersionSupportResponseMiddlewareTests {
  @Test
  func unsupportedAppVersionErrorBlocksTheApp() async throws {
    let clerk = Clerk()
    let middleware = ClerkAppVersionSupportResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    try await middleware.observe(
      response(statusCode: 403),
      data: Data(#"{"errors":[{"code":"unsupported_app_version","message":"Unsupported app version","meta":{"minimum_version":"2.0","update_url":"https://apps.apple.com/app/id123"}}]}"#.utf8),
      for: request()
    )

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0")
    #expect(clerk.appVersionSupportStatus.updateURL?.absoluteString == "https://apps.apple.com/app/id123")
  }

  @Test
  func supportedResponseLiftsTheBlock() async throws {
    let clerk = Clerk()
    clerk.applyUnsupportedAppVersion(meta: nil)
    let middleware = ClerkAppVersionSupportResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    try await middleware.observe(
      response(statusCode: 200, headers: ["X-Clerk-App-Version-Status": "supported"]),
      data: Data(),
      for: request()
    )

    #expect(clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func otherResponsesLeaveTheStatusAlone() async throws {
    let clerk = Clerk()
    clerk.applyUnsupportedAppVersion(meta: nil)
    let middleware = ClerkAppVersionSupportResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    try await middleware.observe(response(statusCode: 200), data: Data(), for: request())
    try await middleware.observe(
      response(statusCode: 403),
      data: Data(#"{"errors":[{"code":"authorization_invalid","message":"Forbidden"}]}"#.utf8),
      for: request()
    )

    #expect(!clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func responsesFromAReplacedRuntimeAreIgnored() async throws {
    let clerk = Clerk()
    let replacedRuntime = ClerkRuntimeScope(state: ClerkRuntimeState(), clerkProvider: { clerk })
    let middleware = ClerkAppVersionSupportResponseMiddleware(runtimeScope: replacedRuntime)

    try await middleware.observe(
      response(statusCode: 403),
      data: Data(#"{"errors":[{"code":"unsupported_app_version","message":"Unsupported app version","meta":{"minimum_version":"2.0"}}]}"#.utf8),
      for: request()
    )
    #expect(clerk.appVersionSupportStatus.isSupported)

    clerk.applyUnsupportedAppVersion(meta: nil)
    try await middleware.observe(
      response(statusCode: 200, headers: ["X-Clerk-App-Version-Status": "supported"]),
      data: Data(),
      for: request()
    )
    #expect(!clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func appResponseMiddlewareThatThrowsCantHideTheBlock() async throws {
    let clerk = Clerk()
    let pipeline = NetworkingPipeline.clerkDefault(runtimeScope: .current(clerkProvider: { clerk }))
      .appendingResponseMiddleware([ThrowingResponseMiddleware()])

    await #expect(throws: ThrowingResponseMiddleware.Rejected.self) {
      try await pipeline.validate(
        response(statusCode: 403),
        data: Data(#"{"errors":[{"code":"unsupported_app_version","message":"Unsupported app version","meta":{"minimum_version":"2.0"}}]}"#.utf8),
        for: request()
      )
    }
    #expect(!clerk.appVersionSupportStatus.isSupported)

    await #expect(throws: ThrowingResponseMiddleware.Rejected.self) {
      try await pipeline.validate(
        response(statusCode: 422, headers: ["X-Clerk-App-Version-Status": "supported"]),
        data: Data(),
        for: request()
      )
    }
    #expect(clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func aLateRejectionCantReblockAfterANewerSupportedAnswer() async throws {
    let clerk = Clerk()
    let middleware = ClerkAppVersionSupportResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    try await middleware.observe(
      response(statusCode: 200, headers: ["X-Clerk-App-Version-Status": "supported"]),
      data: Data(),
      for: request(sequence: 2)
    )
    try await middleware.observe(
      response(statusCode: 403),
      data: Data(#"{"errors":[{"code":"unsupported_app_version","message":"Unsupported app version"}]}"#.utf8),
      for: request(sequence: 1)
    )

    #expect(clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func aLateSupportedAnswerCantLiftANewerRejection() async throws {
    let clerk = Clerk()
    let middleware = ClerkAppVersionSupportResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    try await middleware.observe(
      response(statusCode: 403),
      data: Data(#"{"errors":[{"code":"unsupported_app_version","message":"Unsupported app version"}]}"#.utf8),
      for: request(sequence: 2)
    )
    try await middleware.observe(
      response(statusCode: 200, headers: ["X-Clerk-App-Version-Status": "supported"]),
      data: Data(),
      for: request(sequence: 1)
    )

    #expect(!clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func reconfiguringForgetsTheLastSequence() async throws {
    let clerk = Clerk()
    let middleware = ClerkAppVersionSupportResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    try await middleware.observe(
      response(statusCode: 200, headers: ["X-Clerk-App-Version-Status": "supported"]),
      data: Data(),
      for: request(sequence: 5)
    )
    clerk.resetAppVersionSupport()
    try await middleware.observe(
      response(statusCode: 403),
      data: Data(#"{"errors":[{"code":"unsupported_app_version","message":"Unsupported app version"}]}"#.utf8),
      for: request(sequence: 1)
    )

    #expect(!clerk.appVersionSupportStatus.isSupported)
  }

  private func request(sequence: Int) throws -> URLRequest {
    var request = try request()
    request.setClerkRequestMetadata(sequence: sequence, startupClientRefreshTakeoverID: nil)
    return request
  }

  private func request() throws -> URLRequest {
    try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))
  }

  private func response(statusCode: Int, headers: [String: String]? = nil) throws -> HTTPURLResponse {
    let url = try #require(URL(string: "https://example.com/v1/client"))
    return try #require(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers))
  }
}

private struct ThrowingResponseMiddleware: ClerkResponseMiddleware {
  struct Rejected: Error {}

  func validate(_ response: HTTPURLResponse, data _: Data, for _: URLRequest) async throws {
    if response.statusCode >= 400 {
      throw Rejected()
    }
  }
}
