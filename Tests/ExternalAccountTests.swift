//
//  ExternalAccountTests.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct ExternalAccountTests {

  @Test
  @MainActor
  func testDestroy() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let externalAccount = ExternalAccount.mockVerified
    _ = try? await externalAccount.destroy()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/external_accounts/\(externalAccount.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/external_accounts/\(externalAccount.id)"))
    #expect(verification.hasMethod("DELETE"))
    #expect(verification.hasQueryParameter("_clerk_session_id", value: "1"))
  }
}
