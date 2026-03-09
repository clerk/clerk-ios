@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkClientSyncResponseMiddlewareTests {
  @Test
  func decodeClientFromClientField() throws {
    let expectedClient = client(id: "client-field", updatedAt: .distantFuture)
    let data = try JSONEncoder.clerkEncoder.encode(ClientEnvelope(response: SignIn.mock, client: expectedClient))

    let decodedClient = ClerkClientSyncResponseMiddleware.decodeClient(from: data)
    #expect(decodedClient?.id == expectedClient.id)
  }

  @Test
  func decodeClientFromResponseFieldWhenFetchingClient() throws {
    let expectedClient = client(id: "response-field", updatedAt: .distantFuture)
    let data = try JSONEncoder.clerkEncoder.encode(ClientOnlyEnvelope(response: expectedClient, client: nil))

    let decodedClient = ClerkClientSyncResponseMiddleware.decodeClient(from: data)
    #expect(decodedClient?.id == expectedClient.id)
  }

  @Test
  func decodeClientReturnsNilWhenClientCannotBeDecoded() throws {
    let data = try #require("{}".data(using: .utf8))

    #expect(ClerkClientSyncResponseMiddleware.decodeClient(from: data) == nil)
  }

  @Test
  func validateClearsClientWhenResponseAndClientAreNull() async throws {
    configureClerkForTesting()
    Clerk.shared.client = Client.mock

    let data = try #require("""
    {"response":null,"client":null}
    """.data(using: .utf8))
    let response = try #require(
      try HTTPURLResponse(
        url: #require(URL(string: "https://example.com/v1/client")),
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )
    )
    let request = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))

    try await ClerkClientSyncResponseMiddleware().validate(response, data: data, for: request)

    #expect(Clerk.shared.client == nil)
  }

  @Test
  func validateDoesNotClearClientWhenPayloadHasNoClientField() async throws {
    configureClerkForTesting()
    let existingClient = Client.mock
    Clerk.shared.client = existingClient

    let data = try #require("""
    {"response":{"object":"session","id":"sess_123","status":"active"}}
    """.data(using: .utf8))
    let response = try #require(
      try HTTPURLResponse(
        url: #require(URL(string: "https://example.com/v1/me/sessions/active")),
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )
    )
    let request = try URLRequest(url: #require(URL(string: "https://example.com/v1/me/sessions/active")))

    try await ClerkClientSyncResponseMiddleware().validate(response, data: data, for: request)

    #expect(Clerk.shared.client?.id == existingClient.id)
  }

  private func client(id: String, updatedAt: Date) -> Client {
    var client = Client.mockSignedOut
    client.id = id
    client.updatedAt = updatedAt
    return client
  }
}

private struct ClientEnvelope<Response: Codable>: Codable {
  let response: Response
  let client: Client?
}

private struct ClientOnlyEnvelope: Codable {
  let response: Client
  let client: Client?
}
