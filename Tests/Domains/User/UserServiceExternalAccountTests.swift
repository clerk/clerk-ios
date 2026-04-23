@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct UserServiceExternalAccountTests {
  private let sessionId = "session_test_123"
  private let redirectUrl = "clerk://callback"

  private func makeService(baseURL: URL) -> UserService {
    let apiClient = createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self)
    return UserService(apiClient: apiClient)
  }

  @Test
  func testCreateExternalAccount() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/external_accounts")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>(response: .mockVerified, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == redirectUrl)
      #expect(request.urlEncodedFormBody!["additional_scope"] == nil)
      #expect(request.urlEncodedFormBody!["oidc_prompt"] == nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).createExternalAccount(
      provider: .google,
      redirectUrl: redirectUrl,
      additionalScopes: [],
      oidcPrompts: [],
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func createExternalAccountWithExplicitRedirectUrl() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/external_accounts")
    let explicitRedirectUrl = "custom://redirect"

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>(response: .mockVerified, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == explicitRedirectUrl)
      #expect(request.urlEncodedFormBody!["additional_scope"] == nil)
      #expect(request.urlEncodedFormBody!["oidc_prompt"] == nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).createExternalAccount(
      provider: .google,
      redirectUrl: explicitRedirectUrl,
      additionalScopes: [],
      oidcPrompts: [],
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func createExternalAccountWithAdditionalScopes() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/external_accounts")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>(response: .mockVerified, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == redirectUrl)
      #expect(request.urlEncodedFormBodyMultiValue!["additional_scope"] == ["scope1", "scope2"])
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).createExternalAccount(
      provider: .google,
      redirectUrl: redirectUrl,
      additionalScopes: ["scope1", "scope2"],
      oidcPrompts: [],
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func createExternalAccountWithOIDCPromptArray() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/external_accounts")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>(response: .mockVerified, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == redirectUrl)
      #expect(request.urlEncodedFormBody!["oidc_prompt"] == "consent")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).createExternalAccount(
      provider: .google,
      redirectUrl: redirectUrl,
      additionalScopes: [],
      oidcPrompts: [.consent],
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func createExternalAccountWithOIDCMultiPromptArray() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/external_accounts")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>(response: .mockVerified, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == redirectUrl)
      let promptValues = Set(request.urlEncodedFormBody!["oidc_prompt"]!.split(separator: " ").map(String.init))
      #expect(promptValues == Set(["login", "consent"]))
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).createExternalAccount(
      provider: .google,
      redirectUrl: redirectUrl,
      additionalScopes: [],
      oidcPrompts: [.login, .consent],
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func createExternalAccountWithScopesAndPrompts() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/external_accounts")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>(response: .mockVerified, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == redirectUrl)
      #expect(request.urlEncodedFormBodyMultiValue!["additional_scope"] == ["scope1", "scope2"])
      let promptValues = Set(request.urlEncodedFormBody!["oidc_prompt"]!.split(separator: " ").map(String.init))
      #expect(promptValues == Set(["login", "consent"]))
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).createExternalAccount(
      provider: .google,
      redirectUrl: redirectUrl,
      additionalScopes: ["scope1", "scope2"],
      oidcPrompts: [.login, .consent],
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func createExternalAccountToken() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/external_accounts")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>(response: .mockVerified, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_token_apple")
      #expect(request.urlEncodedFormBody!["token"] == "mock_id_token")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).createExternalAccountToken(
      provider: .apple,
      idToken: "mock_id_token",
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }
}
