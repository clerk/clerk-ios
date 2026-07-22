@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
extension HostedAuthFlowTests {
  @Test
  func createUsesHostedAuthPostRequestShape() async throws {
    configureClerkForTesting()
    let requestHandled = LockIsolated(false)
    let requestUrl = try #require(URL(string: mockBaseUrl.absoluteString + "/v1/client/hosted_auth"))
    let resource = HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
    var mock = try Mock(
      url: requestUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse(response: resource, client: Client.mockSignedOut)),
      ]
    )
    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(!request.shouldAutomaticallySyncClerkClient)
      #expect(!request.shouldLogClerkBodies)
      let queryItems = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems }
      #expect(queryItems == [
        URLQueryItem(name: "_is_native", value: "true"),
      ])
      let body = request.urlEncodedFormBody
      #expect(body?["redirect_url"] == "myapp://callback")
      #expect(body?["code_challenge"] == "challenge_123")
      #expect(body?["state"] == "state_123")
      #expect(body?["mode"] == "sign-up")
      // The wire param is "mode"; guard against regressing to the web SDK's "initial_page".
      #expect(body?["initial_page"] == nil)
      requestHandled.setValue(true)
    }
    mock.register()

    let service = HostedAuthService(apiClient: Clerk.shared.dependencies.apiClient)
    let response = try await service.create(params: HostedAuthCreateParams(
      redirectUrl: "myapp://callback",
      codeChallenge: "challenge_123",
      state: "state_123",
      mode: .signUp
    ))

    #expect(requestHandled.value)
    #expect(response.url == resource.url)
  }

  @Test
  func createOmitsModeWhenNotProvided() throws {
    let params = HostedAuthCreateParams(
      redirectUrl: "myapp://callback",
      codeChallenge: "challenge_123",
      state: "state_123",
      mode: nil
    )
    let encoded = try JSONEncoder.clerkEncoder.encode(params)
    let json = try JSONDecoder.clerkDecoder.decode(JSON.self, from: encoded)

    #expect(json["mode"] == nil)
  }

  @Test
  func redeemUsesPhysicalPostBodyAndDisablesAutomaticClientSync() async throws {
    configureClerkForTesting()
    let requestHandled = LockIsolated(false)
    let requestUrl = try #require(URL(string: mockBaseUrl.absoluteString + "/v1/client"))
    var redeemedClient = Client.mock
    redeemedClient.sessions = [.mock, .mock2]

    var mock = try Mock(
      url: requestUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<Client?>(
          response: redeemedClient,
          client: nil
        )),
      ]
    )
    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.path == requestUrl.path)
      let queryItems = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems }
      #expect(queryItems == [
        URLQueryItem(name: "_is_native", value: "true"),
      ])
      #expect(!request.shouldAutomaticallySyncClerkClient)
      #expect(!request.shouldLogClerkBodies)
      let body = request.urlEncodedFormBody
      #expect(body?["_method"] == "GET")
      #expect(body?["rotating_token_nonce"] == "nonce_123")
      #expect(body?["code_verifier"] == "verifier_123")
      requestHandled.setValue(true)
    }
    mock.register()

    let service = HostedAuthService(apiClient: Clerk.shared.dependencies.apiClient)
    let response = try await service.redeem(params: HostedAuthRedeemParams(
      rotatingTokenNonce: "nonce_123",
      codeVerifier: "verifier_123"
    ))

    #expect(requestHandled.value)
    #expect(response.client?.id == redeemedClient.id)
    #expect(response.client?.sessions.map(\.id) == redeemedClient.sessions.map(\.id))
  }
}
