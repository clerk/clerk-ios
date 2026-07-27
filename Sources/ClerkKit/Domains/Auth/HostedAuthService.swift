//
//  HostedAuthService.swift
//  Clerk
//

import Foundation

protocol HostedAuthServiceProtocol: Sendable {
  @MainActor func create(params: HostedAuthCreateParams) async throws -> HostedAuthResource
  @MainActor func redeem(params: HostedAuthRedeemParams) async throws -> HostedAuthRedeemResponse
}

struct HostedAuthRedeemResponse {
  let client: Client?
  let clientSyncContext: ClientSyncResponseContext
}

final class HostedAuthService: HostedAuthServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func create(params: HostedAuthCreateParams) async throws -> HostedAuthResource {
    let request = Request<ClientResponse<HostedAuthResource>>(
      path: "/v1/client/hosted_auth",
      method: .post,
      body: params,
      automaticallySyncClient: false,
      logBodies: false
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func redeem(params: HostedAuthRedeemParams) async throws -> HostedAuthRedeemResponse {
    let request = Request<ClientResponse<Client?>>(
      path: "/v1/client",
      method: .post,
      headers: [
        ClerkHeaderRequestMiddleware.canonicalClientRequestHeader: "1",
      ],
      body: params,
      automaticallySyncClient: false,
      logBodies: false
    )
    let response = try await apiClient.send(request)
    guard let clientSyncMetadata = response.deferredClientSyncMetadata else {
      throw ClerkClientError(
        message: "Hosted auth completion response was missing identity synchronization metadata."
      )
    }
    let client = response.value.response
    let update: ClientResponseUpdate = if clientSyncMetadata.deviceTokenUpdate == .clear {
      .explicitClear
    } else {
      client.map(ClientResponseUpdate.client) ?? .absent
    }
    return HostedAuthRedeemResponse(
      client: client,
      clientSyncContext: clientSyncMetadata.context(update: update)
    )
  }
}
