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
  ///   - skipCache: Whether the caller asked to bypass caches for this token.
  @MainActor func fetchToken(sessionId: String, template: String?, skipCache: Bool) async throws -> TokenResource?

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

      do {
        try await apiClient.send(request)
      } catch {
        // The server can accept the sign-out and the response pipeline still throw.
        await SessionTokensCache.shared.removeTokens(sessionId: sessionId)
        throw error
      }

      await SessionTokensCache.shared.removeTokens(sessionId: sessionId)
      return
    }

    let request = Request<EmptyResponse>(
      path: "/v1/client/sessions",
      method: .delete
    )

    do {
      try await apiClient.send(request)
    } catch {
      await SessionTokensCache.shared.clear()
      throw error
    }

    await SessionTokensCache.shared.clear()
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
    await SessionTokensCache.shared.removeTokens(sessionId: sessionId)
  }

  @MainActor
  func fetchToken(sessionId: String, template: String?, skipCache: Bool) async throws -> TokenResource? {
    if let template {
      let request = Request<TokenResource?>(
        path: "/v1/client/sessions/\(sessionId)/tokens/\(template)",
        method: .post
      )

      return try await apiClient.send(request).value
    }

    let body = await sessionMinterBody(sessionId: sessionId, skipCache: skipCache)
    let request = Request<TokenResource?>(
      path: "/v1/client/sessions/\(sessionId)/tokens",
      method: .post,
      body: body,
      // The seed is a replayable session credential; keep it out of device logs.
      logBodies: body?["token"] == nil
    )

    return try await apiClient.send(request).value
  }

  /// Body params the session minter needs on the non-template tokens route.
  ///
  /// Returns `nil` when the instance is not on the session minter, or when there is
  /// nothing to send, so the request stays byte-identical to a minter-less one.
  @MainActor
  private func sessionMinterBody(sessionId: String, skipCache: Bool) async -> [String: String]? {
    guard Clerk.shared.environment?.authConfig.sessionMinter == true else {
      return nil
    }

    var body: [String: String] = [:]

    if let seedToken = await sessionMinterSeedToken(sessionId: sessionId) {
      body["token"] = seedToken
    }

    if skipCache {
      body["force_origin"] = "true"
    }

    return body.isEmpty ? nil : body
  }

  /// The previous session token the minter mints from. Never a template token.
  @MainActor
  private func sessionMinterSeedToken(sessionId: String) async -> String? {
    let cacheKey = Session.tokenCacheKey(sessionId: sessionId, template: nil)

    if let cachedToken = await SessionTokensCache.shared.getToken(cacheKey: cacheKey)?.jwt, !cachedToken.isEmpty {
      return cachedToken
    }

    let lastActiveToken = Clerk.shared.client?
      .sessions
      .first { $0.id == sessionId }?
      .lastActiveToken?
      .jwt

    guard let lastActiveToken, !lastActiveToken.isEmpty else {
      return nil
    }

    return lastActiveToken
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
