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
  @Test(arguments: [HTTPMethod.get, .post, .put, .patch, .delete])
  func everyRequestAppliesTheClientByDefault(method: HTTPMethod) throws {
    let request = Request<EmptyResponse>(path: "/v1/me/organization_memberships", method: method)

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
  func organizationListsAskForTheClientOnlyWhenRefreshed() async throws {
    try await expectRequestsAndAppliesTheClient(OrganizationAPI.getMemberships(
      organizationId: "org_1", query: nil, role: nil, offset: 0, pageSize: 10, includeClient: true
    ))
    try await expectRequestsAndAppliesTheClient(OrganizationAPI.getInvitations(
      organizationId: "org_1", offset: 0, pageSize: 10, status: ["pending"], includeClient: true
    ))
    try await expectRequestsAndAppliesTheClient(OrganizationAPI.getMembershipRequests(
      organizationId: "org_1", offset: 0, pageSize: 10, status: "pending", includeClient: true
    ))
    try await expectRequestsAndAppliesTheClient(OrganizationAPI.getDomains(
      organizationId: "org_1", offset: 0, pageSize: 10, enrollmentMode: nil, includeClient: true
    ))

    #expect(try await !includeClientWasSent(by: OrganizationAPI.getMemberships(
      organizationId: "org_1", query: nil, role: nil, offset: 0, pageSize: 10
    )))
    #expect(try await !includeClientWasSent(by: OrganizationAPI.getDomains(
      organizationId: "org_1", offset: 0, pageSize: 10, enrollmentMode: nil
    )))
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
      try await sentQueryItems(of: request).filter { $0.name == "_include_client" }
        == [URLQueryItem(name: "_include_client", value: "true")],
      sourceLocation: sourceLocation
    )
  }

  private func policy(of request: Request<some Decodable & Sendable>) throws -> ClientSyncPolicy {
    try request.makeURLRequest(baseURL: mockBaseUrl, encoder: .clerkEncoder).clerkClientSyncPolicy
  }

  private func includeClientWasSent(by request: Request<some Decodable & Sendable>) async throws -> Bool {
    try await sentQueryItems(of: request).contains { $0.name == "_include_client" }
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
      #expect(request.url?.queryParam(named: "_include_client") == "true")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(UserAPI.reload())
    #expect(requestHandled.value)
  }
}
