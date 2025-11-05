//
//  ClientService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import Foundation

protocol ClientServiceProtocol: Sendable {
  @MainActor func get() async throws -> Client?
}

final class ClientService: ClientServiceProtocol {

  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  // Convenience initializer for dependency injection
  init(dependencies: Dependencies) {
    self.apiClient = dependencies.apiClient
  }

  @MainActor
  func get() async throws -> Client? {
    let request = Request<ClientResponse<Client?>>(path: "/v1/client")
    return try await apiClient.send(request).value.response
  }
}
