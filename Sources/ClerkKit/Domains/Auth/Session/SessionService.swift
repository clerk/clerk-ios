//
//  SessionService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation

extension Container {

  var sessionService: Factory<SessionServiceProtocol> {
    self { SessionService() }
  }

}

protocol SessionServiceProtocol: Sendable {
  @MainActor func revoke(sessionId: String) async throws -> Session
}

final class SessionService: SessionServiceProtocol {

  private var apiClient: APIClient { Container.shared.apiClient() }

  @MainActor
  func revoke(sessionId: String) async throws -> Session {
    let request = Request<ClientResponse<Session>>(
      path: "/v1/me/sessions/\(sessionId)/revoke",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }
}
