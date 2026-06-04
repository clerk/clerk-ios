//
//  MockMagicLinkService.swift
//  Clerk
//

import Foundation

/// Mock implementation of `MagicLinkServiceProtocol` for testing and previews.
package final class MockMagicLinkService: MagicLinkServiceProtocol {
  nonisolated(unsafe) var completeHandler: ((MagicLinkCompleteParams) async throws -> MagicLinkCompleteResponse)?

  init(
    complete: ((MagicLinkCompleteParams) async throws -> MagicLinkCompleteResponse)? = nil
  ) {
    completeHandler = complete
  }

  @MainActor
  func complete(params: MagicLinkCompleteParams) async throws -> MagicLinkCompleteResponse {
    if let completeHandler {
      return try await completeHandler(params)
    }
    return MagicLinkCompleteResponse(flowId: params.flowId, ticket: "ticket_mock")
  }
}
