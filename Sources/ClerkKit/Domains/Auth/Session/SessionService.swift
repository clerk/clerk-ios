import Foundation

protocol SessionServiceProtocol: Sendable {
  @MainActor func setActive(sessionId: String, organizationId: String?) async throws
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
    let clerk = try runtime.requireCurrentClerk()
    try await clerk.identityController.applyNetworkResponse(
      clientSyncMetadata.context(update: clientUpdate)
    )
  }
}
