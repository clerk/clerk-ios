@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct MagicLinkServiceTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func completeCanEstablishClientWhenTokenless() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/magic_links/complete")!
    let response = MagicLinkCompleteResult.ticket(
      MagicLinkCompleteResponse(flowId: "flow_123", ticket: "ticket_123")
    )
    var mock = try Mock(
      url: originalURL,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse<MagicLinkCompleteResult>(response: response, client: .mock)
        ),
      ]
    )
    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.clerkCanEstablishClientWhenTokenless)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.magicLinkService.complete(
      params: MagicLinkCompleteParams(
        flowId: "flow_123",
        approvalToken: "approval_123",
        codeVerifier: "verifier_123"
      )
    )

    #expect(requestHandled.value)
  }
}
