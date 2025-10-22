//
//  ClientService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation
import Get

extension Container {

    var clientService: Factory<ClientService> {
        self { ClientService() }
    }

}

struct ClientService {

    var get: @MainActor () async throws -> Client? = {
        let request = Request<ClientResponse<Client?>>(path: "/v1/client")
        return try await Container.shared.apiClient().send(request).value.response
    }

}
