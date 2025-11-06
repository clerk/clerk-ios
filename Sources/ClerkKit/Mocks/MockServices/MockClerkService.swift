//
//  MockClerkService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Mock implementation of `ClerkServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of service methods through handler closures.
/// All methods are no-op by default if handlers are not provided.
public final class MockClerkService: ClerkServiceProtocol {
  /// Custom handler for the `signOut(sessionId:)` method.
  public nonisolated(unsafe) var signOutHandler: ((String?) async throws -> Void)?

  /// Custom handler for the `setActive(sessionId:organizationId:)` method.
  public nonisolated(unsafe) var setActiveHandler: ((String, String?) async throws -> Void)?

  public init(
    signOut: ((String?) async throws -> Void)? = nil,
    setActive: ((String, String?) async throws -> Void)? = nil
  ) {
    signOutHandler = signOut
    setActiveHandler = setActive
  }

  @MainActor
  public func signOut(sessionId: String?) async throws {
    if let handler = signOutHandler {
      try await handler(sessionId)
    }
    // No-op by default - does not actually sign out
  }

  @MainActor
  public func setActive(sessionId: String, organizationId: String?) async throws {
    if let handler = setActiveHandler {
      try await handler(sessionId, organizationId)
    }
  }
}
