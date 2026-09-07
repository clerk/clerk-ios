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
  func magicLinkCompletionPreservesTicketAndProof() async throws {
    let response = MagicLinkCompleteResult.ticket(.init(flowId: "flow_test", ticket: "ticket_test"))
    var mock = try Mock(
      url: URL(string: mockBaseUrl.absoluteString + "/v1/client/magic_links/complete")!, ignoreQuery: true,
      contentType: .json, statusCode: 200,
      data: [.post: JSONEncoder.clerkEncoder.encode(ClientResponse(response: response, client: nil))]
    )
    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.urlEncodedFormBody?["flow_id"] == "flow_test")
      #expect(request.urlEncodedFormBody?["approval_token"] == "approval_test")
      #expect(request.urlEncodedFormBody?["code_verifier"] == "verifier_test")
      #expect(request.value(forHTTPHeaderField: "authorization") == "fixture-client-jwt")
    }
    mock.register()
    let result = try await Clerk.shared.dependencies.magicLinkService.complete(params: .init(
      flowId: "flow_test", approvalToken: "approval_test", codeVerifier: "verifier_test"
    ))
    #expect(result == response)
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
