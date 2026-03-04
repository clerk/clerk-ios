@testable import ClerkKit
import ConcurrencyExtras
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
    try await withMainSerialExecutor {
      var responseClientApplied = false
      for _ in 0 ..< 3 where !responseClientApplied {
        Clerk.shared.client = nil

        let middleware = ClerkClientSyncResponseMiddleware()
        let fixture = try clientRequestResponseFixture(path: "/v1/client")
        let payload = try JSONEncoder.clerkEncoder.encode(
          ClientResponse<Client?>(response: .mock, client: nil)
        )

        try await middleware.validate(fixture.response, data: payload, for: fixture.request)
        responseClientApplied = Clerk.shared.client?.id == Client.mock.id
      }

      #expect(responseClientApplied)
    }
  }

  @Test
  func explicitNullClientClearsState() async throws {
    try await withMainSerialExecutor {
      var stateCleared = false
      for _ in 0 ..< 3 where !stateCleared {
        Clerk.shared.client = .mock

        let middleware = ClerkClientSyncResponseMiddleware()
        let fixture = try clientRequestResponseFixture(path: "/v1/me")
        let payload = Data(#"{"response":{},"client":null}"#.utf8)

        try await middleware.validate(fixture.response, data: payload, for: fixture.request)
        stateCleared = Clerk.shared.client == nil
      }

      #expect(stateCleared)
    }
  }

  @Test
  func nullResponseWithoutClientDoesNotClearState() async throws {
    try await withMainSerialExecutor {
      var statePreserved = false
      for _ in 0 ..< 3 where !statePreserved {
        Clerk.shared.client = .mock

        let middleware = ClerkClientSyncResponseMiddleware()
        let fixture = try clientRequestResponseFixture(path: "/v1/unknown")
        let payload = Data(#"{"response":null}"#.utf8)

        try await middleware.validate(fixture.response, data: payload, for: fixture.request)
        statePreserved = Clerk.shared.client?.id == Client.mock.id
      }

      #expect(statePreserved)
    }
  }

  @Test
  func olderClientSnapshotDoesNotOverrideNewerState() async throws {
    try await withMainSerialExecutor {
      var newerClient = Client.mock
      newerClient.updatedAt = Date(timeIntervalSince1970: 200)
      newerClient.lastActiveSessionId = "newer-session"
      Clerk.shared.client = newerClient

      var olderClient = Client.mock
      olderClient.updatedAt = Date(timeIntervalSince1970: 100)
      olderClient.lastActiveSessionId = "older-session"

      let middleware = ClerkClientSyncResponseMiddleware()
      let fixture = try clientRequestResponseFixture(path: "/v1/me")
      let payload = try JSONEncoder.clerkEncoder.encode(olderClient)

      try await middleware.validate(fixture.response, data: payload, for: fixture.request)

      let currentClient = try #require(Clerk.shared.client)
      #expect(currentClient.updatedAt == newerClient.updatedAt)
      #expect(currentClient.lastActiveSessionId == newerClient.lastActiveSessionId)
    }
  }

  private func clientRequestResponseFixture(path: String) throws
    -> (request: URLRequest, response: HTTPURLResponse)
  {
    let requestURL = try #require(URL(string: "https://example.com\(path)"))
    let request = URLRequest(url: requestURL)
    let response = try #require(HTTPURLResponse(
      url: requestURL,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))
    return (request: request, response: response)
  }
}
