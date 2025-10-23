//
//  ExternalAccountService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation
import Get

extension Container {

    var externalAccountService: Factory<ExternalAccountService> {
        self { ExternalAccountService() }
    }

}

struct ExternalAccountService {

    var destroy: @MainActor (_ externalAccountId: String) async throws -> DeletedObject = { externalAccountId in
        let request = Request<ClientResponse<DeletedObject>>.init(
            path: "/v1/me/external_accounts/\(externalAccountId)",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

}
