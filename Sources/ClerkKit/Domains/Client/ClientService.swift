//
//  ClientService.swift
//  Clerk
//

import Foundation

package enum ClientServiceUpdate: Equatable {
  case client(Client)
  case cleared
  case preserve

  var client: Client? {
    guard case .client(let client) = self else { return nil }
    return client
  }
}

package struct ClientServiceResponse {
  let update: ClientServiceUpdate
  let requestSequence: Int?
  let serverDate: Date?

  var client: Client? {
    update.client
  }

  init(
    update: ClientServiceUpdate,
    requestSequence: Int?,
    serverDate: Date?
  ) {
    self.update = update
    self.requestSequence = requestSequence
    self.serverDate = serverDate
  }

  init(
    client: Client?,
    requestSequence: Int?,
    serverDate: Date?
  ) {
    self.init(
      update: client.map(ClientServiceUpdate.client) ?? .preserve,
      requestSequence: requestSequence,
      serverDate: serverDate
    )
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
      headers: [
        ClerkHeaderRequestMiddleware.canonicalClientRequestHeader: "1",
        ClerkHeaderRequestMiddleware.skipClientIdHeader: skipClientId ? "1" : "0",
      ]
    )
    let response = try await apiClient.send(request)
    return ClientServiceResponse(
      update: response.value.response.map(ClientServiceUpdate.client) ?? .preserve,
      requestSequence: response.requestSequence,
      serverDate: response.serverDate
    )
  }
}
