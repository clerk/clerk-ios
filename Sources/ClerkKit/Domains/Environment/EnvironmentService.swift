//
//  EnvironmentService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation

extension Container {

    var environmentService: Factory<EnvironmentServiceProtocol> {
        self { EnvironmentService() }
    }

}

protocol EnvironmentServiceProtocol: Sendable {
    @MainActor func get() async throws -> Clerk.Environment
}

final class EnvironmentService: EnvironmentServiceProtocol {

    private var apiClient: APIClient { Container.shared.apiClient() }

    @MainActor
    func get() async throws -> Clerk.Environment {
        let request = Request<Clerk.Environment>(path: "/v1/environment")
        let environment = try await apiClient.send(request).value
        Clerk.shared.environment = environment
        return environment
    }
}
