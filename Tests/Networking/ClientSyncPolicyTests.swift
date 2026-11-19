//
//  ClientSyncPolicyTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
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
  func getRequestsThatNeedTheClientRequestAndApplyIt() throws {
    try expectRequestsAndAppliesTheClient(UserAPI.reload())
    try expectRequestsAndAppliesTheClient(SignInAPI.get(signInId: "sia_1", params: .init()))
    try expectRequestsAndAppliesTheClient(SignInAPI.get(signInId: "sia_1", params: .init(rotatingTokenNonce: "nonce")))
    try expectRequestsAndAppliesTheClient(SignUpAPI.get(signUpId: "sua_1", params: .init()))
    try expectRequestsAndAppliesTheClient(SignUpAPI.get(signUpId: "sua_1", params: .init(rotatingTokenNonce: "nonce")))
  }

  @Test
  func includeClientIsSentAfterTheRequestsOwnQuery() throws {
    let request = SignInAPI.get(signInId: "sia_1", params: .init(rotatingTokenNonce: "nonce"))

    #expect(try queryItems(of: request) == [
      URLQueryItem(name: "rotating_token_nonce", value: "nonce"),
      ClientSyncPolicy.includeClientQueryItem,
    ])
  }

  @Test
  func canonicalClientRequestAppliesTheClientWithoutRequestingIt() throws {
    let request = ClientAPI.get()

    #expect(try policy(of: request) == .apply)
    #expect(try queryItems(of: request).isEmpty)
  }

  @Test
  func otherGetRequestsDoNotRequestTheClient() throws {
    let request = Request<EmptyResponse>(path: "/v1/me/organization_memberships", method: .get)

    #expect(try queryItems(of: request).isEmpty)
  }

  @Test
  func requestWithoutAPolicyAppliesTheClient() throws {
    let request = try URLRequest(url: #require(URL(string: "https://example.com/v1/me")))

    #expect(request.clerkClientSyncPolicy == .apply)
  }

  private func expectRequestsAndAppliesTheClient(
    _ request: Request<some Decodable & Sendable>,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    #expect(try policy(of: request) == .requestAndApply, sourceLocation: sourceLocation)
    #expect(
      try queryItems(of: request).filter { $0.name == ClientSyncPolicy.includeClientQueryItem.name }
        == [ClientSyncPolicy.includeClientQueryItem],
      sourceLocation: sourceLocation
    )
  }

  private func policy(of request: Request<some Decodable & Sendable>) throws -> ClientSyncPolicy {
    try request.makeURLRequest(baseURL: mockBaseUrl, encoder: .clerkEncoder).clerkClientSyncPolicy
  }

  private func queryItems(of request: Request<some Decodable & Sendable>) throws -> [URLQueryItem] {
    let url = try #require(request.makeURLRequest(baseURL: mockBaseUrl, encoder: .clerkEncoder).url)
    return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
  }
}
