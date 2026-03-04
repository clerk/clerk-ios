//
//  ClientService.swift
//  Clerk
//

import Foundation

package struct ClientServiceResponse {
  let client: Client?
  let requestSequence: UInt64?
}

@MainActor
private enum CompatibilityRequestSequence {
  static var nextValue: UInt64 = 0

  static func next() -> UInt64 {
    nextValue &+= 1
    return nextValue
  }
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
  /// This synthesizes a local monotonic `requestSequence` so sequence-based
  /// stale guards continue to apply.
  @MainActor
  func getResponse() async throws -> ClientServiceResponse {
    let requestSequence = CompatibilityRequestSequence.next()
    return try await ClientServiceResponse(
      client: get(),
      requestSequence: requestSequence
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
