//
//  EnvironmentService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import Foundation

protocol EnvironmentServiceProtocol: Sendable {
  @MainActor func get() async throws -> Clerk.Environment
}

final class EnvironmentService: EnvironmentServiceProtocol {

  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  // Convenience initializer for dependency injection
  init(dependencies: Dependencies) {
    self.apiClient = dependencies.apiClient
  }

  @MainActor
  func get() async throws -> Clerk.Environment {
    let request = Request<Clerk.Environment>(path: "/v1/environment")
    let environment = try await apiClient.send(request).value
    Clerk.shared.environment = environment
    return environment
  }
}
