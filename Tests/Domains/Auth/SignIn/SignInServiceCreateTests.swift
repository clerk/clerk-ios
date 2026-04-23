@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct SignInServiceCreateTests {
  private let redirectUrl = "clerk://callback"

  private func makeService(baseURL: URL) -> SignInService {
    SignInService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test
  func createWithIdentifier() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["identifier"] == "test@example.com")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init(identifier: "test@example.com"))
    #expect(requestHandled.value)
  }

  @Test
  func createWithOAuth() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins")
    let expectedRedirectUrl = redirectUrl

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == expectedRedirectUrl)
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init(
      strategy: .oauth(.google),
      redirectUrl: expectedRedirectUrl
    ))
    #expect(requestHandled.value)
  }

  @Test
  func createWithEnterpriseSSO() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins")
    let expectedRedirectUrl = redirectUrl

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "enterprise_sso")
      #expect(request.urlEncodedFormBody!["identifier"] == "user@enterprise.com")
      #expect(request.urlEncodedFormBody!["redirect_url"] == expectedRedirectUrl)
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init(
      identifier: "user@enterprise.com",
      strategy: .enterpriseSSO,
      redirectUrl: expectedRedirectUrl
    ))
    #expect(requestHandled.value)
  }

  @Test
  func createWithIdToken() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_token_apple")
      #expect(request.urlEncodedFormBody!["token"] == "mock_id_token")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init(
      strategy: .idToken(.apple),
      token: "mock_id_token"
    ))
    #expect(requestHandled.value)
  }

  @Test
  func createWithPasskey() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "passkey")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init(strategy: .passkey))
    #expect(requestHandled.value)
  }

  @Test
  func createWithTicket() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "ticket")
      #expect(request.urlEncodedFormBody!["ticket"] == "mock_ticket_value")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init(
      strategy: .ticket,
      ticket: "mock_ticket_value"
    ))
    #expect(requestHandled.value)
  }

  @Test
  func createWithTransfer() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["transfer"] == "1")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init(transfer: true))
    #expect(requestHandled.value)
  }

  @Test
  func createWithNone() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init())
    #expect(requestHandled.value)
  }
}
