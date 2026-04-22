@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct MagicLinkTests {
  init() {
    configureClerkForTesting()
    try! (Clerk.shared.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(
        publishableKey: testPublishableKey,
        options: .init(
          redirectConfig: .init(redirectUrl: "com.clerk.Quickstart://callback")
        )
      )
  }

  @Test
  func parsesFlowIdAndApprovalTokenFromQuery() throws {
    let url = try #require(URL(string: "com.clerk.Quickstart://callback?flow_id=flow_123&approval_token=approval_123"))

    let callback = try MagicLinkCallback(url: url)

    #expect(callback.flowId == "flow_123")
    #expect(callback.approvalToken == "approval_123")
    #expect(url.queryParam(named: "flow_id") == "flow_123")
    #expect(url.queryParam(named: "approval_token") == "approval_123")
  }

  @Test
  func parsesFlowIdAndApprovalTokenFromFragment() throws {
    let url = try #require(URL(string: "com.clerk.Quickstart://callback#flow_id=flow_123&approval_token=approval_123"))

    let callback = try MagicLinkCallback(url: url)

    #expect(callback.flowId == "flow_123")
    #expect(callback.approvalToken == "approval_123")
    #expect(url.queryParam(named: "flow_id") == "flow_123")
    #expect(url.queryParam(named: "approval_token") == "approval_123")
  }

  @Test(arguments: [
    "com.clerk.Quickstart://callback?flow_id=flow_123&approval_token=approval_123",
    "com.clerk.Quickstart://callback/?flow_id=flow_123&approval_token=approval_123",
    "com.clerk.Quickstart:/callback?flow_id=flow_123&approval_token=approval_123",
    "com.clerk.Quickstart://wrong?flow_id=flow_123&approval_token=approval_123",
    "com.clerk.Quickstart://callback#flow_id=flow_123&approval_token=approval_123",
  ])
  @MainActor
  func routeMatcherAcceptsEquivalentCustomSchemeCallbacks(_ callbackUrl: String) throws {
    let url = try #require(URL(string: callbackUrl))

    let route = try ClerkURLRoute(url: url)

    guard case .magicLink(let flowId, let approvalToken) = route else {
      Issue.record("Expected magic link route")
      return
    }

    #expect(flowId == "flow_123")
    #expect(approvalToken == "approval_123")
  }

  @Test
  @MainActor
  func routeMatcherRejectsDifferentCustomScheme() throws {
    let url = try #require(URL(string: "com.clerk.Other://callback?flow_id=flow_123&approval_token=approval_123"))

    let route = try ClerkURLRoute(url: url)

    #expect(route == nil)
  }

  @Test
  func missingFlowIdThrowsDeterministicError() throws {
    let url = try #require(URL(string: "com.clerk.Quickstart://callback?approval_token=approval_123"))

    #expect(throws: ClerkClientError.self) {
      try MagicLinkCallback(url: url)
    }
  }
}
