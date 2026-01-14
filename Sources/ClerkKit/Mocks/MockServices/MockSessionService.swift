//
//  MockSessionService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Mock implementation of `SessionServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of service methods through handler closures.
/// All methods return default mock values if handlers are not provided.
package final class MockSessionService: SessionServiceProtocol {
  /// Custom handler for the `revoke(sessionId:)` method.
  package nonisolated(unsafe) var revokeHandler: ((String) async throws -> Session)?

  /// Custom handler for the `signOut(sessionId:)` method.
  package nonisolated(unsafe) var signOutHandler: ((String?) async throws -> Void)?

  /// Custom handler for the `setActive(sessionId:organizationId:)` method.
  package nonisolated(unsafe) var setActiveHandler: ((String, String?) async throws -> Void)?

  /// Custom handler for the `fetchToken(sessionId:template:)` method.
  package nonisolated(unsafe) var fetchTokenHandler: ((String, String?) async throws -> TokenResource?)?

  package init(
    revoke: ((String) async throws -> Session)? = nil,
    signOut: ((String?) async throws -> Void)? = nil,
    setActive: ((String, String?) async throws -> Void)? = nil,
    fetchToken: ((String, String?) async throws -> TokenResource?)? = nil
  ) {
    revokeHandler = revoke
    signOutHandler = signOut
    setActiveHandler = setActive
    fetchTokenHandler = fetchToken
  }

  @MainActor
  package func revoke(sessionId: String) async throws -> Session {
    if let handler = revokeHandler {
      return try await handler(sessionId)
    }
    return .mock
  }

  @MainActor
  package func signOut(sessionId: String?) async throws {
    if let handler = signOutHandler {
      try await handler(sessionId)
    }
    // No-op by default - does not actually sign out
  }

  @MainActor
  package func setActive(sessionId: String, organizationId: String?) async throws {
    if let handler = setActiveHandler {
      try await handler(sessionId, organizationId)
    }
  }

  @MainActor
  package func fetchToken(sessionId: String, template: String?) async throws -> TokenResource? {
    if let handler = fetchTokenHandler {
      return try await handler(sessionId, template)
    }

    return .mock
  }
}
