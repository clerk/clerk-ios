//
//  ClerkService.swift
//  Clerk
//
//  Created by Mike Pitre on 2/26/25.
//

import Factory
import Foundation
import Get

struct ClerkService {
  var saveClientIdToKeychain: (_ clientId: String) throws -> Void
  var signOut: (_ sessionId: String?) async throws -> Void
  var setActive: (_ sessionId: String, _ organizationId: String?) async throws -> Void
}

extension ClerkService {

  static var liveValue: Self {
    .init(
      saveClientIdToKeychain: { clientId in
        try Container.shared.keychain().set(clientId, forKey: "clientId")
      },
      signOut: { sessionId in
        if let sessionId {
          let request = ClerkFAPI.v1.client.sessions.id(sessionId).remove.post
          try await Container.shared.apiClient().send(request)
        } else {
          let request = ClerkFAPI.v1.client.sessions.delete
          try await Container.shared.apiClient().send(request)
        }
      },
      setActive: { sessionId, organizationId in
        let request = Request<ClientResponse<Session>>(
          path: "v1/client/sessions/\(sessionId)/touch",
          method: .post,
          body: ["active_organization_id": organizationId ?? ""]  // nil key/values get dropped, use an empty string to set no active org
        )
        try await Container.shared.apiClient().send(request)
      }
    )
  }

}

extension Container {

  var clerkService: Factory<ClerkService> {
    self { .liveValue }
  }

}
