@testable import ClerkKit
import Foundation
import Testing

struct ServerClockTests {
  private let receivedAt = Date(timeIntervalSince1970: 1000)

  @Test
  func usesTheDeviceClockBeforeAnyResponse() {
    #expect(ServerClock().deviceLag == 0)
  }

  @Test
  func recordsHowFarTheDeviceLagsTheServer() {
    var clock = ServerClock()

    clock.record(serverDate: receivedAt.addingTimeInterval(300), receivedAt: receivedAt)

    #expect(clock.deviceLag == 300)
  }

  @Test
  func serverDateBehindTheDeviceCountsAsNoLag() {
    var clock = ServerClock()

    clock.record(serverDate: receivedAt.addingTimeInterval(-300), receivedAt: receivedAt)

    #expect(clock.deviceLag == 0)
  }

  @Test
  func latestResponseReplacesAnEarlierLag() {
    var clock = ServerClock()
    clock.record(serverDate: receivedAt.addingTimeInterval(300), receivedAt: receivedAt)

    clock.record(serverDate: receivedAt, receivedAt: receivedAt)

    #expect(clock.deviceLag == 0)
  }
}

@MainActor
@Suite(.serialized)
struct ClerkServerClockResponseMiddlewareTests {
  init() {
    configureClerkForTesting()
    Clerk.shared.identityController.resetServerClock()
  }

  @Test
  func responseWithAnUnreadableOrMissingDateKeepsTheKnownLag() async throws {
    defer { Clerk.shared.identityController.resetServerClock() }
    let middleware = ClerkServerClockResponseMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    let serverNow = Date.now.addingTimeInterval(300)

    try await middleware.observe(response(dateHeader: HTTPURLResponse.httpDateFormatter.string(from: serverNow)), data: Data(), for: request)
    let knownLag = Clerk.shared.identityController.serverClock.deviceLag
    #expect(knownLag > 290)

    try await middleware.observe(response(dateHeader: "not a date"), data: Data(), for: request)
    try await middleware.observe(response(dateHeader: nil), data: Data(), for: request)

    #expect(Clerk.shared.identityController.serverClock.deviceLag == knownLag)
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
