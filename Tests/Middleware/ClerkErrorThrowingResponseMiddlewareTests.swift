@testable import ClerkKit
import Foundation
import Testing

struct ClerkErrorThrowingResponseMiddlewareTests {
  @Test(arguments: [404, 500])
  func thrownAPIErrorCarriesTheResponseStatus(statusCode: Int) async throws {
    let url = try #require(URL(string: "https://example.com/v1/environment"))
    let response = try #require(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil))
    let body = Data(#"{"errors":[{"code":"resource_not_found","message":"Not found"}],"clerk_trace_id":"trace_1"}"#.utf8)

    let error = await #expect(throws: ClerkAPIError.self) {
      try await ClerkErrorThrowingResponseMiddleware().validate(response, data: body, for: URLRequest(url: url))
    }

    #expect(error?.statusCode == statusCode)
    #expect(error?.clerkTraceId == "trace_1")
  }
}
