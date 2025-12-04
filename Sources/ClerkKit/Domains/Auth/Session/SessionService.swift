//
//  SessionService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
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
  ///   - organizationId: Optional organization ID to set as active in the session.
  @MainActor func setActive(sessionId: String, organizationId: String?) async throws
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
    let request = Request<EmptyResponse>(
      path: "/v1/client/sessions/\(sessionId)/touch",
      method: .post,
      body: ["active_organization_id": organizationId ?? ""]
    )

    try await apiClient.send(request)
  }
}
