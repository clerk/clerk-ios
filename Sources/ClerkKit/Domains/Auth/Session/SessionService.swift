//
//  SessionService.swift
//  Clerk
//

import Foundation

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
  @MainActor func fetchToken(sessionId: String, template: String?) async throws -> TokenResource?

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
    } else {
      let request = Request<EmptyResponse>(
        path: "/v1/client/sessions",
        method: .delete
      )

      try await apiClient.send(request)
    }
  }

  @MainActor
  func setActive(sessionId: String, organizationId: String?) async throws {
    let request = Request<ClientResponse<Session>>(
      path: "/v1/client/sessions/\(sessionId)/touch",
      method: .post,
      body: [
        "active_organization_id": organizationId ?? "",
        "intent": "select_org",
      ]
    )

    try await apiClient.send(request)
  }

  @MainActor
  func fetchToken(sessionId: String, template: String?) async throws -> TokenResource? {
    let path = if let template {
      "/v1/client/sessions/\(sessionId)/tokens/\(template)"
    } else {
      "/v1/client/sessions/\(sessionId)/tokens"
    }

    let request = Request<TokenResource?>(
      path: path,
      method: .post
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
