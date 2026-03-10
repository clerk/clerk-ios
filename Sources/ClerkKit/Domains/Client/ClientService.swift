//
//  ClientService.swift
//  Clerk
//

import Foundation

package struct ClientServiceResponse {
  let client: Client?
  let requestSequence: Int?
}

protocol ClientServiceProtocol: Sendable {
  @MainActor func getResponse() async throws -> ClientServiceResponse
}

final class ClientService: ClientServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  /// Fetches only the client payload, discarding response ordering metadata.
  @MainActor
  func get() async throws -> Client? {
    try await getResponse().client
  }

  /// Fetches the client payload plus request ordering metadata.
  @MainActor
  func getResponse() async throws -> ClientServiceResponse {
    let request = Request<ClientResponse<Client?>>(path: "/v1/client")
    let response = try await apiClient.send(request)
    return ClientServiceResponse(
      client: response.value.response,
      requestSequence: response.requestSequence
    )
  }
}
