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
public final class MockSessionService: SessionServiceProtocol {
  /// Custom handler for the `revoke(sessionId:)` method.
  public nonisolated(unsafe) var revokeHandler: ((String) async throws -> Session)?

  public init(revoke: ((String) async throws -> Session)? = nil) {
    revokeHandler = revoke
  }

  @MainActor
  public func revoke(sessionId: String) async throws -> Session {
    if let handler = revokeHandler {
      return try await handler(sessionId)
    }
    return .mock
  }
}
