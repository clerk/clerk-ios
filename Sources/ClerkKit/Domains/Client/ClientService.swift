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
  @MainActor func get() async throws -> Client?
  /// Returns the client payload alongside an ordering token.
  ///
  /// Production conformers should provide a monotonic `requestSequence` so
  /// `Clerk` can reject out-of-order clears and snapshots. Returning `nil`
  /// sequence values disables causal ordering checks for that response.
  @MainActor func getResponse() async throws -> ClientServiceResponse
}

extension ClientServiceProtocol {
  /// Compatibility fallback for legacy/test conformers that only implement `get()`.
  ///
  /// This does not provide ordering metadata, so responses produced by this
  /// default path bypass sequence-based stale guards.
  @MainActor
  func getResponse() async throws -> ClientServiceResponse {
    try await ClientServiceResponse(
      client: get(),
      requestSequence: nil
    )
  }
}

final class ClientService: ClientServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func get() async throws -> Client? {
    let response = try await getResponse()
    return response.client
  }

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
