//
//  MagicLinkService.swift
//  Clerk
//

import Foundation

protocol MagicLinkServiceProtocol: Sendable {
  @MainActor func complete(params: MagicLinkCompleteParams) async throws -> MagicLinkCompleteResult
}

final class MagicLinkService: MagicLinkServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func complete(params: MagicLinkCompleteParams) async throws -> MagicLinkCompleteResult {
    let request = Request<ClientResponse<MagicLinkCompleteResult>>(
      path: "/v1/client/magic_links/complete",
      method: .post,
      canEstablishClientWhenTokenless: true,
      body: params
    )

    return try await apiClient.send(request).value.response
  }
}
