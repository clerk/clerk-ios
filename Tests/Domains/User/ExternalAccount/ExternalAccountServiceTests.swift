@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct ExternalAccountServiceTests {
  private let sessionId = "session_test_123"
  private let redirectUrl = "clerk://callback"

  private func makeService(baseURL: URL) -> ExternalAccountService {
    ExternalAccountService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test
  func reauthorizeWithAdditionalScopes() async throws {
    let externalAccount = ExternalAccount.mockVerified
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/external_accounts/\(externalAccount.id)/reauthorize")

    try registerIsolatedStub(
      url: originalURL,
      method: .patch,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>(response: .mockVerified, client: .mock))
    ) { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["redirect_url"] == redirectUrl)
      let scopes = request.urlEncodedFormBodyMultiValue!["additional_scope"]
      #expect(Set(scopes ?? []) == Set(["write", "view"]))
      #expect(request.urlEncodedFormBody!["oidc_prompt"] == nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).reauthorize(
      externalAccount.id,
      redirectUrl: redirectUrl,
      additionalScopes: ["write", "view"],
      oidcPrompts: [],
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func testDestroy() async throws {
    let externalAccount = ExternalAccount.mockVerified
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/external_accounts/\(externalAccount.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .delete,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).destroy(externalAccount.id, sessionId: sessionId)
    #expect(requestHandled.value)
  }
}
