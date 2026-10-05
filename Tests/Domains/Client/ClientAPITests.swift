@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct ClientAPITests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func getResponse() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClientResponse<Client?>(response: .mock, client: .mock)),
      ],
      additionalHeaders: ["Authorization": "client-token"]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(ClientAPI.get())
    #expect(requestHandled.value)
  }

  @Test
  func getResponseIncludesRequestSequence() async throws {
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client")!

    let mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClientResponse<Client?>(response: .mock, client: .mock)),
      ],
      additionalHeaders: ["Authorization": "client-token"]
    )
    mock.register()

    let response = try await Clerk.shared.dependencies.transport.send(ClientAPI.get())

    #expect(response.value.response?.id == Client.mock.id)
    #expect(response.requestSequence == 1)
  }
}
