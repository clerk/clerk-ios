//
//  MagicLinkService.swift
//  Clerk
//

import Foundation

protocol MagicLinkServiceProtocol: Sendable {
  @MainActor func complete(params: MagicLinkCompleteParams) async throws -> MagicLinkCompleteResponse
}

final class MagicLinkService: MagicLinkServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func complete(params: MagicLinkCompleteParams) async throws -> MagicLinkCompleteResponse {
    let request = Request<ClientResponse<MagicLinkCompleteResponse>>(
      path: "/v1/client/magic_links/complete",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }
}
