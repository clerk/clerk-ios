//
//  MockMagicLinkService.swift
//  Clerk
//

import Foundation

/// Mock implementation of `MagicLinkServiceProtocol` for testing and previews.
package final class MockMagicLinkService: MagicLinkServiceProtocol {
  private let completeHandler: (@Sendable @MainActor (MagicLinkCompleteParams) async throws -> MagicLinkCompleteResult)?

  init(
    complete: (@Sendable @MainActor (MagicLinkCompleteParams) async throws -> MagicLinkCompleteResult)? = nil
  ) {
    completeHandler = complete
  }

  @MainActor
  func complete(params: MagicLinkCompleteParams) async throws -> MagicLinkCompleteResult {
    if let completeHandler {
      return try await completeHandler(params)
    }
    return .ticket(MagicLinkCompleteResponse(flowId: params.flowId, ticket: "ticket_mock"))
  }
}
