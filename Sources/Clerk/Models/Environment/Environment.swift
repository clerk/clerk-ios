//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import Factory
import Foundation

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
    return try await Container.shared.environmentService().get()
  }

}

extension Clerk.Environment {

  static var mock: Self {
    .init(
      authConfig: nil,
      userSettings: .mock,
      displayConfig: .mock,
      fraudSettings: nil
    )
  }

}
