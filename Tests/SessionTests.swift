//
//  SessionTests.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct SessionTests {

  @Test
  @MainActor
  func testRevoke() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var session = Session.mock
    _ = try? await session.revoke()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/sessions/\(session.id)/revoke", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/sessions/\(session.id)/revoke"))
    #expect(verification.hasMethod("POST"))
    #expect(verification.hasQueryParameter("_clerk_session_id", value: "1"))
  }
}

