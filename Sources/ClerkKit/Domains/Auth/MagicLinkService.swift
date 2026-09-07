//
//  MagicLinkService.swift
//  Clerk
//

import Foundation

protocol MagicLinkServiceProtocol: Sendable {
  @MainActor func complete(params: MagicLinkCompleteParams) async throws -> MagicLinkCompleteResult
}

final class MagicLinkService: MagicLinkServiceProtocol {
  init(apiClient _: APIClient) {}

  @MainActor
  func complete(params: MagicLinkCompleteParams) async throws -> MagicLinkCompleteResult {
    try await Clerk.js(.clerk, JSRawCall("completeNativeMagicLink", JSONValue(encoding: params)), as: MagicLinkCompleteResult.self)
  }
}
