//
//  ClerkService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation

extension Container {
  
  var clerkService: Factory<ClerkService> {
    self { @MainActor in ClerkService() }
  }
  
}

@MainActor
struct ClerkService {
  
  var signOut: (_ sessionId: String?) async throws -> Void = { sessionId in
    if let sessionId {
      _ = try await Container.shared.apiClient().request()
        .add(path: "/v1/client/sessions/\(sessionId)/remove")
        .method(.post)
        .data(type: ClientResponse<Session>.self)
        .async()
    } else {
      _ = try await Container.shared.apiClient().request()
        .add(path: "/v1/client/sessions")
        .method(.delete)
        .data(type: ClientResponse<Client>.self)
        .async()
    }
  }
  
  var setActive: (_ sessionId: String, _ organizationId: String?) async throws -> Void = { sessionId, organizationId in
    _ = try await Container.shared.apiClient().request()
      .add(path: "/v1/client/sessions/\(sessionId)/touch")
      .method(.post)
      .body(formEncode: ["active_organization_id": organizationId])
      .data(type: ClientResponse<Session>.self)
      .async()
  }
  
}
