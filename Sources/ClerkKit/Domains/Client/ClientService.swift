//
//  ClientService.swift
//  Clerk
//

import Foundation

package struct ClientServiceResponse {
  let client: Client?
  let requestSequence: Int?
  let serverDate: Date?
}

protocol ClientServiceProtocol: Sendable {
  /// Fetches the client response.
  ///
  /// - Parameter skipClientId: When `true`, the request omits the current
  ///   `x-clerk-client-id` header. Use this when the stored device token may
  ///   have changed before the in-memory client has been refreshed.
  /// - Parameter suppressDeviceTokenPersistence: When `true`, ignores an
  ///   `Authorization` response header for this request. Use this while
  ///   refreshing after a device-token clear so the clear remains durable.
  @MainActor func getResponse(skipClientId: Bool, suppressDeviceTokenPersistence: Bool) async throws -> ClientServiceResponse
}

extension ClientServiceProtocol {
  @MainActor func getResponse() async throws -> ClientServiceResponse {
    try await getResponse(skipClientId: false, suppressDeviceTokenPersistence: false)
  }

  @MainActor func getResponse(skipClientId: Bool) async throws -> ClientServiceResponse {
    try await getResponse(skipClientId: skipClientId, suppressDeviceTokenPersistence: false)
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
  func getResponse(skipClientId: Bool = false, suppressDeviceTokenPersistence: Bool = false) async throws -> ClientServiceResponse {
    var headers: [String: String] = [:]
    if skipClientId {
      headers[ClerkHeaderRequestMiddleware.skipClientIdHeader] = "1"
    }
    if suppressDeviceTokenPersistence {
      headers[ClerkHeaderRequestMiddleware.suppressDeviceTokenPersistenceHeader] = "1"
    }

    let request = Request<ClientResponse<Client?>>(
      path: "/v1/client",
      headers: headers
    )
    let response = try await apiClient.send(request)
    return ClientServiceResponse(
      client: response.value.response,
      requestSequence: response.requestSequence,
      serverDate: response.serverDate
    )
  }
}
