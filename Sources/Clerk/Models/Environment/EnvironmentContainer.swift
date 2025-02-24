//
//  EnvironmentContainer.swift
//  Clerk
//
//  Created by Mike Pitre on 2/24/25.
//

import Factory
import Foundation

final class EnvironmentContainer: SharedContainer {
  public static let shared = EnvironmentContainer()
  public let manager = ContainerManager()
  
  var get: Factory<() async throws -> Clerk.Environment> {
    self {{
      let request = ClerkFAPI.v1.environment.get
      return try await Clerk.shared.apiClient.send(request).value
    }}
  }
}
