//
//  ExternalAccountService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import Foundation

protocol ExternalAccountServiceProtocol: Sendable {
  @MainActor func destroy(_ externalAccountId: String) async throws -> DeletedObject
}

final class ExternalAccountService: ExternalAccountServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func destroy(_ externalAccountId: String) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/external_accounts/\(externalAccountId)",
      method: .delete,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }
}
