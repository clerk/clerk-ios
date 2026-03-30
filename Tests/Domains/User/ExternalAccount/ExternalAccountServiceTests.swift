@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct ExternalAccountServiceTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func reauthorizeWithAdditionalScopes() async throws {
    let externalAccount = ExternalAccount.mockVerified
    let requestHandled = LockIsolated(false)
    let originalURL = URL(
      string: mockBaseUrl.absoluteString + "/v1/me/external_accounts/\(externalAccount.id)/reauthorize"
    )!
    let expectedRedirectUrl = Clerk.shared.options.redirectConfig.redirectUrl

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>(response: .mockVerified, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["redirect_url"] == expectedRedirectUrl)
      let scopes = request.urlEncodedFormBodyMultiValue!["additional_scope"]
      #expect(Set(scopes ?? []) == Set(["write", "view"]))
      #expect(request.urlEncodedFormBody!["oidc_prompt"] == nil)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.externalAccountService.reauthorize(
      externalAccount.id,
      redirectUrl: nil,
      additionalScopes: ["write", "view"],
      oidcPrompts: []
    )
    #expect(requestHandled.value)
  }

  @Test
  func testDestroy() async throws {
    let externalAccount = ExternalAccount.mockVerified
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/external_accounts/\(externalAccount.id)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.externalAccountService.destroy(externalAccount.id)
    #expect(requestHandled.value)
  }
}
