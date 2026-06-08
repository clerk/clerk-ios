@testable import ClerkKit
import Foundation
import Testing

private let magicLinkRedirectUrl = "com.clerk.Quickstart://callback"

@MainActor
@Suite(.serialized)
struct MagicLinkTests {
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
    "com.clerk.Quickstart://callback#flow_id=flow_123&approval_token=approval_123",
  ])
  @MainActor
  func routeMatcherAcceptsConfiguredCustomSchemeCallbacks(_ callbackUrl: String) throws {
    let url = try #require(URL(string: callbackUrl))

    let route = try ClerkURLRoute(url: url, redirectUrl: magicLinkRedirectUrl)

    guard case .magicLink(let flowId, let approvalToken) = route else {
      Issue.record("Expected magic link route")
      return
    }

    #expect(flowId == "flow_123")
    #expect(approvalToken == "approval_123")
  }

  @Test(arguments: [
    "com.clerk.Quickstart:/callback?flow_id=flow_123&approval_token=approval_123",
    "com.clerk.Quickstart://wrong?flow_id=flow_123&approval_token=approval_123",
    "com.clerk.Quickstart://callback/extra?flow_id=flow_123&approval_token=approval_123",
  ])
  @MainActor
  func routeMatcherRejectsDifferentCustomSchemeEndpoint(_ callbackUrl: String) throws {
    let url = try #require(URL(string: callbackUrl))

    let route = try ClerkURLRoute(url: url, redirectUrl: magicLinkRedirectUrl)

    #expect(route == nil)
  }

  @Test
  @MainActor
  func routeMatcherRejectsDifferentCustomScheme() throws {
    let url = try #require(URL(string: "com.clerk.Other://callback?flow_id=flow_123&approval_token=approval_123"))

    let route = try ClerkURLRoute(url: url, redirectUrl: magicLinkRedirectUrl)

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
