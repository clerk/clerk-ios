import FactoryKit
import FactoryTesting
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct ClerkAPIClientTests {

  init() {
    configureClerkForTesting()
  }

  @Test(.container)
  func testRequestHeaders() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder().encode(["success": true])
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/x-www-form-urlencoded")
      #expect(request.allHTTPHeaderFields?["clerk-api-version"] == "2025-04-10")
      #expect(request.allHTTPHeaderFields?["x-ios-sdk-version"] == Clerk.version)
      #expect(request.allHTTPHeaderFields?["x-mobile"] == "1")
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .post
    )

    _ = try await Container.shared.apiClient().send(request)
    #expect(requestHandled.value)
  }
}
