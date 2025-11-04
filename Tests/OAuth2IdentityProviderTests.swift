import FactoryKit
import Foundation
import Mocker
import Testing

@testable import Clerk

@Suite(.serialized) struct OAuth2IdentityProviderTests {

  init() {
    // Ensure mocked API client is used (auto-registered via TestUtilities)
    Container.shared.reset(context: .test)
  }

  deinit {
    Container.shared.reset()
  }

  @MainActor
  @Test func testObtainTokenRequest() async throws {
    let originalUrl = mockBaseUrl.appending(path: "/v1/oauth/token")

    var requestHandled = false

    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(OAuth2TokenResponse.mock)
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      // Body should be URL-encoded and contain our parameters
      if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
        #expect(bodyString.contains("grant_type=client_credentials"))
        #expect(bodyString.contains("connection_id=con_123"))
      } else {
        Issue.record("Request body missing")
      }

      requestHandled = true
    }

    mock.register()

    let params: [String: String] = [
      "grant_type": "client_credentials",
      "connection_id": "con_123",
      "scope": "read:all"
    ]

    let token = try await Clerk.shared.obtainOAuth2Token(parameters: params)
    #expect(token.accessToken == OAuth2TokenResponse.mock.accessToken)
    #expect(requestHandled)
  }
}
