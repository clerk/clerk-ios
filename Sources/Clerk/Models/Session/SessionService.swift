//
//  SessionService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation

extension Container {
  
  var sessionService: Factory<SessionService> {
    self { @MainActor in SessionService() }
  }
  
}

@MainActor
struct SessionService {
  
  var revoke: (_ sessionId: String) async throws -> Session = { sessionId in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/sessions/\(sessionId)/revoke")
      .method(.post)
      .addClerkSessionId()
      .data(type: ClientResponse<Session>.self)
      .async()
      .response
  }
  
} 