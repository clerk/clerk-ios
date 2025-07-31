//
//  EnvironmentService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation
import Get

extension Container {

    var environmentService: Factory<EnvironmentService> {
        self { EnvironmentService() }
    }

}

struct EnvironmentService {

    var get: @MainActor () async throws -> Clerk.Environment = {
        let request = Request<Clerk.Environment>(path: "/v1/environment")
        let environment = try await Container.shared.apiClient().send(request).value
        Clerk.shared.environment = environment
        return environment
    }

}
