@testable import ClerkKit
import Foundation
import Testing

struct MagicLinkTests {
  @Test
  func parsesFlowIdAndApprovalTokenFromQuery() throws {
    let url = try #require(URL(string: "com.clerk.Quickstart://callback?flow_id=flow_123&approval_token=approval_123"))

    let callback = try MagicLinkCallback(url: url)

    #expect(callback.flowId == "flow_123")
    #expect(callback.approvalToken == "approval_123")
    #expect(MagicLinkCallback.canHandle(url))
  }

  @Test
  func fragmentOnlyCallbackIsNotHandled() throws {
    let url = try #require(URL(string: "com.clerk.Quickstart://callback#flow_id=flow_123&approval_token=approval_123"))

    #expect(MagicLinkCallback.canHandle(url) == false)
  }

  @Test
  func missingFlowIdThrowsDeterministicError() throws {
    let url = try #require(URL(string: "com.clerk.Quickstart://callback?approval_token=approval_123"))

    #expect(throws: ClerkClientError.self) {
      try MagicLinkCallback(url: url)
    }
  }
}
