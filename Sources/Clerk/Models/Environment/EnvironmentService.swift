//
//  EnvironmentService.swift
//  Clerk
//
//  Created by Mike Pitre on 2/26/25.
//

import Factory
import Foundation

struct EnvironmentService {
  var get: @MainActor () async throws -> Clerk.Environment
}

extension EnvironmentService {

  static var liveValue: Self {
    .init(
      get: {
        let request = ClerkFAPI.v1.environment.get
        let environment = try await Container.shared.apiClient().send(request).value
        Clerk.shared.environment = environment
        return environment
      }
    )
  }

}

extension Container {

  var environmentService: Factory<EnvironmentService> {
    self { .liveValue }
  }

}
