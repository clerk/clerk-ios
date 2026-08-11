//
//  SessionService.swift
//  Clerk
//

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
  @MainActor func revoke(sessionId: String) async throws -> Session

  /// Signs out the active user.
  /// - Parameter sessionId: Optional session ID to sign out from a specific session.
  @MainActor func signOut(sessionId: String?) async throws

  /// Sets the active session and optionally the active organization.
  /// - Parameters:
  ///   - sessionId: The session ID to set as active.
  ///   - organizationId: Optional organization ID to set as active in the session. If nil, removes the active organization.
  @MainActor func setActive(sessionId: String, organizationId: String?) async throws

  /// Creates a session token for the given session and optional template.
  /// - Parameters:
  ///   - sessionId: The session ID to generate a token for.
  ///   - template: Optional JWT template name.
  ///   - params: Parameters used when generating the default session token.
  @MainActor func fetchToken(
    sessionId: String,
    template: String?,
    params: SessionTokenRequestParams?
  ) async throws -> TokenResource?

  /// Starts an in-session reverification (step-up) flow.
  @MainActor func startVerification(
    sessionId: String,
    params: Session.StartVerificationParams
  ) async throws -> SessionVerification

  /// Prepares the first factor of an in-session reverification flow.
  @MainActor func prepareFirstFactorVerification(
    sessionId: String,
    params: Session.PrepareFirstFactorVerificationParams
  ) async throws -> SessionVerification

  /// Attempts the first factor of an in-session reverification flow.
  @MainActor func attemptFirstFactorVerification(
    sessionId: String,
    params: Session.AttemptFirstFactorVerificationParams
  ) async throws -> SessionVerification

  /// Prepares the second factor of an in-session reverification flow.
  @MainActor func prepareSecondFactorVerification(
    sessionId: String,
    params: Session.PrepareSecondFactorVerificationParams
  ) async throws -> SessionVerification

  /// Attempts the second factor of an in-session reverification flow.
  @MainActor func attemptSecondFactorVerification(
    sessionId: String,
    params: Session.AttemptSecondFactorVerificationParams
  ) async throws -> SessionVerification
}

final class SessionService: SessionServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func revoke(sessionId: String) async throws -> Session {
    let request = Request<ClientResponse<Session>>(
      path: "/v1/me/sessions/\(sessionId)/revoke",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func signOut(sessionId: String?) async throws {
    if let sessionId {
      let request = Request<EmptyResponse>(
        path: "/v1/client/sessions/\(sessionId)/remove",
        method: .post
      )

      try await apiClient.send(request)
      await SessionTokensCache.shared.removeTokens(sessionId: sessionId)
    } else {
      let request = Request<EmptyResponse>(
        path: "/v1/client/sessions",
        method: .delete
      )

      try await apiClient.send(request)
      await SessionTokensCache.shared.clear()
    }
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

  @MainActor
  func startVerification(
    sessionId: String,
    params: Session.StartVerificationParams
  ) async throws -> SessionVerification {
    let request = Request<ClientResponse<SessionVerification>>(
      path: "/v1/client/sessions/\(sessionId)/verify",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func prepareFirstFactorVerification(
    sessionId: String,
    params: Session.PrepareFirstFactorVerificationParams
  ) async throws -> SessionVerification {
    let request = Request<ClientResponse<SessionVerification>>(
      path: "/v1/client/sessions/\(sessionId)/verify/prepare_first_factor",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptFirstFactorVerification(
    sessionId: String,
    params: Session.AttemptFirstFactorVerificationParams
  ) async throws -> SessionVerification {
    let request = Request<ClientResponse<SessionVerification>>(
      path: "/v1/client/sessions/\(sessionId)/verify/attempt_first_factor",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func prepareSecondFactorVerification(
    sessionId: String,
    params: Session.PrepareSecondFactorVerificationParams
  ) async throws -> SessionVerification {
    let request = Request<ClientResponse<SessionVerification>>(
      path: "/v1/client/sessions/\(sessionId)/verify/prepare_second_factor",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptSecondFactorVerification(
    sessionId: String,
    params: Session.AttemptSecondFactorVerificationParams
  ) async throws -> SessionVerification {
    let request = Request<ClientResponse<SessionVerification>>(
      path: "/v1/client/sessions/\(sessionId)/verify/attempt_second_factor",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }
}
