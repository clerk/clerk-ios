//
//  MockEnvironmentService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

package final class MockEnvironmentService: EnvironmentServiceProtocol {
  package nonisolated(unsafe) var getHandler: (() async throws -> Clerk.Environment)?

  package init(get: (() async throws -> Clerk.Environment)? = nil) {
    getHandler = get
  }

  @MainActor
  package func get() async throws -> Clerk.Environment {
    if let handler = getHandler {
      return try await handler()
    }
    return .mock
  }
}
