//
//  HostedAuthService.swift
//  Clerk
//

import Foundation

protocol HostedAuthServiceProtocol: Sendable {
  @MainActor func create(params: HostedAuthCreateParams) async throws -> HostedAuthResource
  @MainActor func redeem(params: HostedAuthRedeemParams) async throws -> ClientServiceResponse
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
  func redeem(params: HostedAuthRedeemParams) async throws -> ClientServiceResponse {
    let request = Request<ClientResponse<Client?>>(
      path: "/v1/client",
      method: .post,
      body: params,
      automaticallySyncClient: false,
      logBodies: false
    )
    let response = try await apiClient.send(request)
    return ClientServiceResponse(
      client: response.value.response,
      requestSequence: response.requestSequence,
      serverDate: response.serverDate
    )
  }
}
