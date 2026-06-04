@testable import ClerkKit
import Testing

@Suite(.serialized)
struct MockMagicLinkServiceTests {
  @Test
  func completeUsesInjectedHandler() async throws {
    let service = MockMagicLinkService { params in
      #expect(params.flowId == "flow_custom")
      #expect(params.approvalToken == "approval_custom")
      #expect(params.codeVerifier == "verifier_custom")

      return MagicLinkCompleteResponse(flowId: "flow_custom", ticket: "ticket_custom")
    }

    let response = try await service.complete(
      params: MagicLinkCompleteParams(
        flowId: "flow_custom",
        approvalToken: "approval_custom",
        codeVerifier: "verifier_custom"
      )
    )

    #expect(response == MagicLinkCompleteResponse(flowId: "flow_custom", ticket: "ticket_custom"))
  }
}
