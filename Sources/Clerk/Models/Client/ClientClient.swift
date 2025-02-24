//
//  ClientClient.swift
//  Clerk
//
//  Created by Mike Pitre on 2/23/25.
//

import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
struct ClientClient {
  var get: @Sendable () async throws -> Client?
}

extension ClientClient: DependencyKey, TestDependencyKey {
  
  static var liveValue: ClientClient {
    .init(
      get: {
        let request = ClerkFAPI.v1.client.get
        return try await Clerk.shared.apiClient.send(request).value.response
      }
    )
  }
  
  static let testValue = Self()
}

extension DependencyValues {
  var clientClient: ClientClient {
    get { self[ClientClient.self] }
    set { self[ClientClient.self] = newValue }
  }
}
