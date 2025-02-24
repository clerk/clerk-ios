//
//  EnvironmentClient.swift
//  Clerk
//
//  Created by Mike Pitre on 2/24/25.
//

import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
struct EnvironmentClient {
  var get: @Sendable () async throws -> Clerk.Environment
}

extension EnvironmentClient: DependencyKey, TestDependencyKey {
  
  static var liveValue: EnvironmentClient {
    @Dependency(\.apiClientProvider) var apiClientProvider
    
    return .init(
      get: {
        let request = ClerkFAPI.v1.environment.get
        return try await Clerk.shared.apiClient.send(request).value
      }
    )
  }
  
  static let testValue = Self()
}

extension DependencyValues {
  var environmentClient: EnvironmentClient {
    get { self[EnvironmentClient.self] }
    set { self[EnvironmentClient.self] = newValue }
  }
}
