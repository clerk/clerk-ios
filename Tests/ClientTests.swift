//
//  ClientTests.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct ClientTests {

  @Test
  @MainActor
  func testGet() async throws {
    TestContainer.reset()

    _ = try? await Client.get()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/client"))
    #expect(verification.hasMethod("GET"))
  }
}
