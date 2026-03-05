//
//  ClientService.swift
//  Clerk
//

import Foundation

package struct ClientServiceResponse {
  let client: Client?
  let requestSequence: UInt64?
}

protocol ClientServiceProtocol: Sendable {
  /// Returns the client payload alongside an ordering token.
  ///
  /// Conformers used by runtime networking paths should provide a monotonic
  /// `requestSequence` so `Clerk` can reject out-of-order clears and
  /// snapshots. Returning `nil` sequence values disables causal ordering
  /// checks for that response.
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
    let response = try await getResponse()
    return response.client
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
