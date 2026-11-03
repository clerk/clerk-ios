@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkServerClockResponseMiddlewareTests {
  private let receivedAt = Date(timeIntervalSince1970: 1000)

  @Test
  func responseWithAnUnreadableOrMissingDateKeepsTheKnownLag() async throws {
    let clerk = Clerk()
    let middleware = ClerkServerClockResponseMiddleware(
      runtimeScope: .current(clerkProvider: { clerk }),
      currentDate: { [receivedAt] in receivedAt }
    )
    let serverDate = receivedAt.addingTimeInterval(300)

    try await middleware.observe(response(dateHeader: HTTPURLResponse.httpDateFormatter.string(from: serverDate)), data: Data(), for: request)
    #expect(clerk.identityController.serverClock.deviceLag == 300)

    try await middleware.observe(response(dateHeader: "not a date"), data: Data(), for: request)
    try await middleware.observe(response(dateHeader: nil), data: Data(), for: request)

    #expect(clerk.identityController.serverClock.deviceLag == 300)
  }

  private var request: URLRequest {
    URLRequest(url: mockBaseUrl)
  }

  private func response(dateHeader: String?) throws -> HTTPURLResponse {
    try #require(HTTPURLResponse(
      url: mockBaseUrl,
      statusCode: 200,
      httpVersion: nil,
      headerFields: dateHeader.map { ["Date": $0] }
    ))
  }
}
