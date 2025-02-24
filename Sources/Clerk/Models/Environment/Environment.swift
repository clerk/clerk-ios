//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import Foundation
import Dependencies

extension Clerk {
  
  struct Environment: Codable, Sendable {
    var authConfig: AuthConfig?
    var userSettings: UserSettings?
    var displayConfig: DisplayConfig?
    var fraudSettings: FraudSettings?
  }
  
}

extension Clerk.Environment {
  
  @MainActor
  static func get() async throws -> Clerk.Environment {
    @Dependency(\.environmentClient) var environmentClient
    return try await environmentClient.get()
  }
  
}
