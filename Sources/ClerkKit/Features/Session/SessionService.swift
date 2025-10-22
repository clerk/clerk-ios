//
//  SessionService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation
import Get

extension Container {

    var sessionService: Factory<SessionService> {
        self { SessionService() }
    }

}

struct SessionService {

    var revoke: @MainActor (_ sessionId: String) async throws -> Session = { sessionId in
        let request = Request<ClientResponse<Session>>.init(
            path: "/v1/me/sessions/\(sessionId)/revoke",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

}
