//
//  EnvironmentService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation

extension Container {
  
  var environmentService: Factory<EnvironmentService> {
    self { @MainActor in EnvironmentService() }
  }
  
}

@MainActor
struct EnvironmentService {
  
  var get: () async throws -> Clerk.Environment = {
    let environment = try await Container.shared.apiClient().request()
      .add(path: "/v1/environment")
      .data(type: Clerk.Environment.self)
      .async()
    
    Clerk.shared.environment = environment
    return environment
  }
  
} 