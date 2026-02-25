@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkErrorThrowingResponseMiddlewareTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func unsupportedAppVersionErrorUpdatesAppVersionSupportStatus() async throws {
    let middleware = ClerkErrorThrowingResponseMiddleware()
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let request = URLRequest(url: url)
    let response = try #require(
      HTTPURLResponse(
        url: url,
        statusCode: 426,
        httpVersion: nil,
        headerFields: nil
      )
    )

    let payload = """
    {
      "errors": [
        {
          "code": "unsupported_app_version",
          "message": "unsupported app version",
          "meta": {
            "platform": "ios",
            "app_identifier": "\(DeviceHelper.bundleID)",
            "current_version": "1.0.0",
            "minimum_version": "2.0.0",
            "update_url": "https://apps.apple.com/app/id123"
          }
        }
      ]
    }
    """

    do {
      try middleware.validate(response, data: Data(payload.utf8), for: request)
      #expect(Bool(false), "Expected middleware to throw ClerkAPIError")
    } catch {
      #expect(error is ClerkAPIError)
    }

    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(Clerk.shared.appVersionSupportStatus.isSupported == false)
    #expect(Clerk.shared.appVersionSupportStatus.minimumVersion == "2.0.0")
  }
}
