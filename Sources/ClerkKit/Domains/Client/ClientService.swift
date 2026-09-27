//
//  ClientService.swift
//  Clerk
//

import Foundation

protocol ClientServiceProtocol: Sendable {
  /// Fetches through the response middleware, which applies or rejects the identity
  /// before returning. Callers must not apply the returned network snapshot again.
  @MainActor func get(skipClientId: Bool) async throws -> Client?
}

extension ClientServiceProtocol {
  @MainActor func get() async throws -> Client? {
    try await get(skipClientId: false)
  }
}

final class ClientService: ClientServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  /// Omitting the Client ID lets the server resolve a newly stored device token.
  @MainActor
  func get(skipClientId: Bool = false) async throws -> Client? {
    let request = Request<ClientResponse<Client?>>(
      path: "/v1/client",
      headers: [
        ClerkHeaderRequestMiddleware.canonicalClientRequestHeader: "1",
        ClerkHeaderRequestMiddleware.skipClientIdHeader: skipClientId ? "1" : "0",
      ]
    )
    return try await apiClient.send(request).value.response
  }
}
