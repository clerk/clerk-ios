//
//  SessionService.swift
//  Clerk
//
//  Created by Mike Pitre on 3/11/25.
//

import Factory
import Foundation

struct SessionService {
  var revoke: (_ session: Session) async throws -> Session
}

extension SessionService {
  
  static var liveValue: Self {
    .init(
      revoke: { session in
        let request = ClerkFAPI.v1.me.sessions.withId(id: session.id).revoke.post(
            queryItems: [.init(name: "_clerk_session_id", value: await Clerk.shared.session?.id)]
        )
        return try await Container.shared.apiClient().send(request).value.response
      }
    )
  }
  
}

extension Container {
  
  var sessionService: Factory<SessionService> {
    self { .liveValue }
  }
  
}
