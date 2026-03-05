@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkClientSyncResponseMiddlewareTests {
  @MainActor
  private static var requestSequence: UInt64 = 0

  init() {
    configureClerkForTesting()
    Clerk.shared.resetClientResponseSequenceTracking()
  }

  @Test
  func responseClientTakesPrecedenceOverNullClient() async throws {
    try await withMainSerialExecutor {
      Clerk.shared.client = nil

      let middleware = ClerkClientSyncResponseMiddleware()
      let fixture = try clientRequestResponseFixture(path: "/v1/client")
      let payload = try JSONEncoder.clerkEncoder.encode(
        ClientResponse<Client?>(response: .mock, client: nil)
      )

      try await middleware.validate(fixture.response, data: payload, for: fixture.request)
      #expect(Clerk.shared.client?.id == Client.mock.id)
    }
  }

  @Test
  func explicitNullClientDoesNotClearState() async throws {
    try await withMainSerialExecutor {
      Clerk.shared.client = .mock

      let middleware = ClerkClientSyncResponseMiddleware()
      let fixture = try clientRequestResponseFixture(path: "/v1/me")
      let payload = Data(#"{"response":{},"client":null}"#.utf8)

      try await middleware.validate(fixture.response, data: payload, for: fixture.request)
      #expect(Clerk.shared.client?.id == Client.mock.id)
    }
  }

  @Test
  func nullResponseWithoutClientDoesNotClearState() async throws {
    try await withMainSerialExecutor {
      Clerk.shared.client = .mock

      let middleware = ClerkClientSyncResponseMiddleware()
      let fixture = try clientRequestResponseFixture(path: "/v1/unknown")
      let payload = Data(#"{"response":null}"#.utf8)

      try await middleware.validate(fixture.response, data: payload, for: fixture.request)
      #expect(Clerk.shared.client?.id == Client.mock.id)
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

  @Test
  func olderNullSnapshotDoesNotClearNewerState() async throws {
    try await withMainSerialExecutor {
      var currentClient = Client.mock
      currentClient.updatedAt = Date(timeIntervalSince1970: 300)
      currentClient.lastActiveSessionId = "current-session"
      Clerk.shared.client = currentClient

      let middleware = ClerkClientSyncResponseMiddleware()
      let staleFixture = try clientRequestResponseFixture(
        path: "/v1/me",
        requestSequence: 1
      )
      let staleClearPayload = Data(#"{"response":{},"client":null}"#.utf8)

      let freshFixture = try clientRequestResponseFixture(
        path: "/v1/me",
        requestSequence: 2
      )
      var newerClient = Client.mock
      newerClient.updatedAt = Date(timeIntervalSince1970: 400)
      newerClient.lastActiveSessionId = "newer-session"
      let newerPayload = try JSONEncoder.clerkEncoder.encode(newerClient)

      try await middleware.validate(freshFixture.response, data: newerPayload, for: freshFixture.request)
      try await middleware.validate(staleFixture.response, data: staleClearPayload, for: staleFixture.request)

      let resultingClient = try #require(Clerk.shared.client)
      #expect(resultingClient.updatedAt == newerClient.updatedAt)
      #expect(resultingClient.lastActiveSessionId == newerClient.lastActiveSessionId)
    }
  }

  @MainActor
  private static func nextRequestSequence() -> UInt64 {
    requestSequence &+= 1
    return requestSequence
  }

  private func clientRequestResponseFixture(
    path: String,
    requestSequence: UInt64? = nil
  ) throws
    -> (request: URLRequest, response: HTTPURLResponse)
  {
    let requestURL = try #require(URL(string: "https://example.com\(path)"))
    var request = URLRequest(url: requestURL)
    request.setRequestSequence(requestSequence ?? Self.nextRequestSequence())
    let response = try #require(HTTPURLResponse(
      url: requestURL,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))
    return (request: request, response: response)
  }
}
