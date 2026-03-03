@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkClientSyncResponseMiddlewareTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func responseClientTakesPrecedenceOverNullClient() async throws {
    Clerk.shared.client = nil

    let middleware = ClerkClientSyncResponseMiddleware()
    let requestURL = try #require(URL(string: "https://example.com/v1/client"))
    let request = URLRequest(url: requestURL)
    let response = try #require(HTTPURLResponse(
      url: requestURL,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))
    let payload = try JSONEncoder.clerkEncoder.encode(
      ClientResponse<Client?>(response: .mock, client: nil)
    )

    try await middleware.validate(response, data: payload, for: request)

    #expect(Clerk.shared.client?.id == Client.mock.id)
  }

  @Test
  func explicitNullClientClearsState() async throws {
    Clerk.shared.client = .mock

    let middleware = ClerkClientSyncResponseMiddleware()
    let requestURL = try #require(URL(string: "https://example.com/v1/me"))
    let request = URLRequest(url: requestURL)
    let response = try #require(HTTPURLResponse(
      url: requestURL,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))
    let payload = Data(#"{"response":{},"client":null}"#.utf8)

    try await middleware.validate(response, data: payload, for: request)

    #expect(Clerk.shared.client == nil)
  }

  @Test
  func nullResponseWithoutClientDoesNotClearState() async throws {
    Clerk.shared.client = .mock

    let middleware = ClerkClientSyncResponseMiddleware()
    let requestURL = try #require(URL(string: "https://example.com/v1/unknown"))
    let request = URLRequest(url: requestURL)
    let response = try #require(HTTPURLResponse(
      url: requestURL,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))
    let payload = Data(#"{"response":null}"#.utf8)

    try await middleware.validate(response, data: payload, for: request)

    #expect(Clerk.shared.client?.id == Client.mock.id)
  }
}
