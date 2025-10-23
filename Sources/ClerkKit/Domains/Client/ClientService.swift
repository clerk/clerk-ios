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

    var clientService: Factory<ClientServiceProtocol> {
        self { ClientService() }
    }

}

protocol ClientServiceProtocol: Sendable {
    @MainActor func get() async throws -> Client?
}

final class ClientService: ClientServiceProtocol {

    private var apiClient: APIClient { Container.shared.apiClient() }

    @MainActor
    func get() async throws -> Client? {
        let request = Request<ClientResponse<Client?>>(path: "/v1/client")
        return try await apiClient.send(request).value.response
    }
}
