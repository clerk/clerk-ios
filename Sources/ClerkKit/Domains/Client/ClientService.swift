//
//  ClientService.swift
//  Clerk
//

import Foundation

package struct ClientServiceResponse {
  let client: Client?
  let requestSequence: Int?
  let serverDate: Date?
  let wasAppliedByResponseMiddleware: Bool

  init(
    client: Client?,
    requestSequence: Int?,
    serverDate: Date?,
    wasAppliedByResponseMiddleware: Bool = false
  ) {
    self.client = client
    self.requestSequence = requestSequence
    self.serverDate = serverDate
    self.wasAppliedByResponseMiddleware = wasAppliedByResponseMiddleware
  }
}

protocol ClientServiceProtocol: Sendable {
  /// Fetches the client response.
  ///
  /// - Parameter skipClientId: When `true`, the request omits the current
  ///   `x-clerk-client-id` header. Use this when the stored device token may
  ///   have changed before the in-memory client has been refreshed.
  @MainActor func getResponse(skipClientId: Bool) async throws -> ClientServiceResponse
}

extension ClientServiceProtocol {
  @MainActor func getResponse() async throws -> ClientServiceResponse {
    try await getResponse(skipClientId: false)
  }
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
  ///
  /// - Parameter skipClientId: When `true`, requests the header middleware to
  ///   skip `x-clerk-client-id` for this request. The middleware still sends the
  ///   stored device token, allowing the backend to resolve the client from that
  ///   token without also receiving a possibly stale client id.
  @MainActor
  func getResponse(skipClientId: Bool = false) async throws -> ClientServiceResponse {
    let request = Request<ClientResponse<Client?>>(
      path: "/v1/client",
      headers: skipClientId ? [ClerkHeaderRequestMiddleware.skipClientIdHeader: "1"] : [:]
    )
    let response = try await apiClient.send(request)
    return ClientServiceResponse(
      client: response.value.response,
      requestSequence: response.requestSequence,
      serverDate: response.serverDate,
      wasAppliedByResponseMiddleware: true
    )
  }
}
