@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct ClientServiceTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func testGet() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClientResponse<Client?>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.clientService.get()
    #expect(requestHandled.value)
  }

  @Test
  func prepareAuthenticatedWebURLReturnsInitializedURL() async throws {
    let requestHandled = LockIsolated(false)
    let endpointURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/prepare_webview")!
    let initializedURL = "https://pumped-deer-84.accounts.lclclerk.com/v1/client/initialize_webview?token=token_123"
    var mock = try Mock(
      url: endpointURL,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONSerialization.data(withJSONObject: ["response": ["redirect_url": initializedURL]]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody?["redirect_url"] == "https://example.com/checkout")
      requestHandled.setValue(true)
    }
    mock.register()

    let service = ClientService(apiClient: Clerk.shared.dependencies.apiClient)
    let url = try await service.prepareAuthenticatedWebURL(for: #require(URL(string: "https://example.com/checkout")))

    #expect(requestHandled.value)
    #expect(url.absoluteString == initializedURL)
  }

  @Test
  func prepareAuthenticatedWebURLThrowsForInvalidRedirectURL() async throws {
    let endpointURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/prepare_webview")!
    let mock = try Mock(
      url: endpointURL,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONSerialization.data(withJSONObject: ["response": ["redirect_url": "::invalid::"]]),
      ]
    )
    mock.register()

    let service = ClientService(apiClient: Clerk.shared.dependencies.apiClient)
    do {
      _ = try await service.prepareAuthenticatedWebURL(for: #require(URL(string: "https://example.com")))
      Issue.record("Expected prepareAuthenticatedWebURL to throw for an invalid redirect URL.")
    } catch {
      #expect(error.localizedDescription.contains("Authenticated web URL is invalid."))
    }
  }
}
