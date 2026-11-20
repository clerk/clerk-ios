//
//  ClientSyncPolicyTests.swift
//  Clerk
//

@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

struct ClientSyncPolicyTests {
  @Test
  func getRequestsIgnoreTheClientOnSuccessByDefault() throws {
    let request = Request<EmptyResponse>(path: "/v1/me/organization_memberships", method: .get)

    #expect(try policy(of: request) == .ignoreOnSuccess)
  }

  @Test(arguments: [HTTPMethod.post, .put, .patch, .delete])
  func nonGetRequestsApplyTheClientByDefault(method: HTTPMethod) throws {
    let request = Request<EmptyResponse>(path: "/v1/me", method: method)

    #expect(try policy(of: request) == .apply)
  }

  @Test
  func getRequestsThatNeedTheClientRequestAndApplyIt() async throws {
    try await expectRequestsAndAppliesTheClient(UserAPI.reload())
    try await expectRequestsAndAppliesTheClient(SignInAPI.get(signInId: "sia_1", params: .init()))
    try await expectRequestsAndAppliesTheClient(SignInAPI.get(signInId: "sia_1", params: .init(rotatingTokenNonce: "nonce")))
    try await expectRequestsAndAppliesTheClient(SignUpAPI.get(signUpId: "sua_1", params: .init()))
    try await expectRequestsAndAppliesTheClient(SignUpAPI.get(signUpId: "sua_1", params: .init(rotatingTokenNonce: "nonce")))
  }

  @Test
  func requestingTheClientKeepsTheRequestsOwnQuery() async throws {
    let request = SignInAPI.get(signInId: "sia_1", params: .init(rotatingTokenNonce: "nonce"))

    #expect(try await sentQueryItems(of: request).contains(URLQueryItem(name: "rotating_token_nonce", value: "nonce")))
  }

  @Test
  func canonicalClientRequestAppliesTheClientWithoutRequestingIt() async throws {
    let request = ClientAPI.get()

    #expect(try policy(of: request) == .apply)
    #expect(try await !includeClientWasSent(by: request))
  }

  @Test(arguments: [HTTPMethod.get, .post])
  func requestsWithTheirDefaultPolicyDoNotRequestTheClient(method: HTTPMethod) async throws {
    let request = Request<EmptyResponse>(path: "/v1/me/organization_memberships", method: method)

    #expect(try await !includeClientWasSent(by: request))
  }

  @Test
  func requestWithoutAPolicyAppliesTheClient() throws {
    let request = try URLRequest(url: #require(URL(string: "https://example.com/v1/me")))

    #expect(request.clerkClientSyncPolicy == .apply)
  }

  private func expectRequestsAndAppliesTheClient(
    _ request: Request<some Decodable & Sendable>,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async throws {
    #expect(try policy(of: request) == .requestAndApply, sourceLocation: sourceLocation)
    #expect(
      try await sentQueryItems(of: request).filter { $0.name == ClientSyncPolicy.includeClientQueryItem.name }
        == [ClientSyncPolicy.includeClientQueryItem],
      sourceLocation: sourceLocation
    )
  }

  private func policy(of request: Request<some Decodable & Sendable>) throws -> ClientSyncPolicy {
    try request.makeURLRequest(baseURL: mockBaseUrl, encoder: .clerkEncoder).clerkClientSyncPolicy
  }

  private func includeClientWasSent(by request: Request<some Decodable & Sendable>) async throws -> Bool {
    try await sentQueryItems(of: request).contains { $0.name == ClientSyncPolicy.includeClientQueryItem.name }
  }

  private func sentQueryItems(of request: Request<some Decodable & Sendable>) async throws -> [URLQueryItem] {
    var urlRequest = try request.makeURLRequest(baseURL: mockBaseUrl, encoder: .clerkEncoder)
    try await ClerkQueryItemsRequestMiddleware().prepare(&urlRequest)
    let url = try #require(urlRequest.url)
    return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
  }
}

@MainActor
@Suite(.serialized)
struct ClientSyncPolicySentRequestTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func userReloadSendsTheIncludeClientOptIn() async throws {
    Clerk.shared.client = .mock
    let requestHandled = LockIsolated(false)
    let meURL = try #require(URL(string: mockBaseUrl.absoluteString + "/v1/me"))

    var mock = try Mock(
      url: meURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClientResponse<User>(response: .mock, client: .mock)),
      ]
    )
    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.url?.queryParam(named: ClientSyncPolicy.includeClientQueryItem.name) == "true")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(UserAPI.reload())
    #expect(requestHandled.value)
  }
}
