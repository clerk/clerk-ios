import Foundation

package struct SessionTokenRequestParams: Encodable, Equatable {
  package var organizationId: String
  package var token: String?
  package var forceOrigin: String?

  package init(
    organizationId: String,
    token: String? = nil,
    forceOrigin: String? = nil
  ) {
    self.organizationId = organizationId
    self.token = token
    self.forceOrigin = forceOrigin
  }
}

protocol SessionServiceProtocol: Sendable {
  @MainActor func setActive(sessionId: String, organizationId: String?) async throws
  @MainActor func fetchToken(
    sessionId: String,
    template: String?,
    params: SessionTokenRequestParams?
  ) async throws -> TokenResource?
}

final class SessionService: SessionServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func setActive(sessionId: String, organizationId: String?) async throws {
    let runtime = try Clerk.requireStableRuntime()
    let request = Request<ClientResponse<Session>>(
      path: "/v1/client/sessions/\(sessionId)/touch",
      method: .post,
      body: [
        "active_organization_id": organizationId ?? "",
        "intent": "select_org",
      ],
      automaticallySyncClient: false
    )

    let response = try await apiClient.send(request)
    guard let clientSyncMetadata = response.deferredClientSyncMetadata else {
      throw ClerkClientError(
        message: "Session activation response was missing identity synchronization metadata."
      )
    }
    let clientUpdate: ClientResponseUpdate =
      if clientSyncMetadata.deviceTokenUpdate == .clear {
        .explicitClear
      } else {
        response.value.client.map(ClientResponseUpdate.client) ?? .absent
      }

    try runtime.validateStableRuntime()
    await SessionTokensCache.shared.removeTokens(sessionId: sessionId)
    let clerk = try runtime.requireCurrentClerk()
    try await clerk.identityController.applyNetworkResponse(
      clientSyncMetadata.context(update: clientUpdate)
    )
  }

  @MainActor
  func fetchToken(
    sessionId: String,
    template: String?,
    params: SessionTokenRequestParams?
  ) async throws -> TokenResource? {
    let path = if let template {
      "/v1/client/sessions/\(sessionId)/tokens/\(template)"
    } else {
      "/v1/client/sessions/\(sessionId)/tokens"
    }
    let body = template == nil ? params : nil

    let request = Request<TokenResource?>(
      path: path,
      method: .post,
      body: body,
      logBodies: false
    )

    return try await apiClient.send(request).value
  }
}
