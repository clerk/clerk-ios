//
//  EnvironmentService.swift
//  Clerk
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

  @MainActor
  func get() async throws -> Clerk.Environment {
    let request = Request<Clerk.Environment>(path: "/v1/environment")
    return try await apiClient.send(request).value
  }
}
