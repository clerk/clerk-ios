#if !os(watchOS)
@testable import ClerkKit
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct NativeResourceServiceTests {
  init() async throws {
    try await configureEmbeddedClerkForTesting()
  }

  @Test
  func passkeyVerificationPreservesCredentialAndResource() async throws {
    let response = Passkey.mock
    let credential = "{\"id\":\"credential_test\",\"rawId\":\"YQ\"}"
    var mock = try Mock(
      url: URL(string: mockBaseUrl.absoluteString + "/v1/me/passkeys/" + response.id + "/attempt_verification")!, ignoreQuery: true,
      contentType: .json, statusCode: 200,
      data: [.post: JSONEncoder.clerkEncoder.encode(ClientResponse(response: response, client: nil))]
    )
    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.urlEncodedFormBody?["strategy"] == "passkey")
      #expect(request.urlEncodedFormBody?["public_key_credential"] == credential)
      #expect(request.url?.queryParam(named: "_clerk_session_id") == "sess_fixture")
    }
    mock.register()
    let result = try await response.attemptVerification(credential: credential)
    #expect(result.id == response.id)
    #expect(result.verification == response.verification)
  }
}
#endif
