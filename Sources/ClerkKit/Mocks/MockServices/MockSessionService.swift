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

  /// Custom handler for the `startVerification(sessionId:params:)` method.
  nonisolated(unsafe) var startVerificationHandler: ((String, Session.StartVerificationParams) async throws -> SessionVerification)?

  /// Custom handler for the `prepareFirstFactorVerification(sessionId:params:)` method.
  nonisolated(unsafe) var prepareFirstFactorVerificationHandler: ((String, Session.PrepareFirstFactorVerificationParams) async throws -> SessionVerification)?

  /// Custom handler for the `attemptFirstFactorVerification(sessionId:params:)` method.
  nonisolated(unsafe) var attemptFirstFactorVerificationHandler: ((String, Session.AttemptFirstFactorVerificationParams) async throws -> SessionVerification)?

  /// Custom handler for the `prepareSecondFactorVerification(sessionId:params:)` method.
  nonisolated(unsafe) var prepareSecondFactorVerificationHandler: ((String, Session.PrepareSecondFactorVerificationParams) async throws -> SessionVerification)?

  /// Custom handler for the `attemptSecondFactorVerification(sessionId:params:)` method.
  nonisolated(unsafe) var attemptSecondFactorVerificationHandler: ((String, Session.AttemptSecondFactorVerificationParams) async throws -> SessionVerification)?

  package convenience init(
    revoke: ((String) async throws -> Session)? = nil,
    signOut: ((String?) async throws -> Void)? = nil,
    setActive: ((String, String?) async throws -> Void)? = nil,
    fetchToken: ((String, String?) async throws -> TokenResource?)? = nil
  ) {
    self.init(
      revoke: revoke,
      signOut: signOut,
      setActive: setActive,
      fetchToken: fetchToken,
      startVerification: nil,
      prepareFirstFactorVerification: nil,
      attemptFirstFactorVerification: nil,
      prepareSecondFactorVerification: nil,
      attemptSecondFactorVerification: nil
    )
  }

  init(
    revoke: ((String) async throws -> Session)? = nil,
    signOut: ((String?) async throws -> Void)? = nil,
    setActive: ((String, String?) async throws -> Void)? = nil,
    fetchToken: ((String, String?) async throws -> TokenResource?)? = nil,
    startVerification: ((String, Session.StartVerificationParams) async throws -> SessionVerification)? = nil,
    prepareFirstFactorVerification: ((String, Session.PrepareFirstFactorVerificationParams) async throws -> SessionVerification)? = nil,
    attemptFirstFactorVerification: ((String, Session.AttemptFirstFactorVerificationParams) async throws -> SessionVerification)? = nil,
    prepareSecondFactorVerification: ((String, Session.PrepareSecondFactorVerificationParams) async throws -> SessionVerification)? = nil,
    attemptSecondFactorVerification: ((String, Session.AttemptSecondFactorVerificationParams) async throws -> SessionVerification)? = nil
  ) {
    revokeHandler = revoke
    signOutHandler = signOut
    setActiveHandler = setActive
    fetchTokenHandler = fetchToken
    startVerificationHandler = startVerification
    prepareFirstFactorVerificationHandler = prepareFirstFactorVerification
    attemptFirstFactorVerificationHandler = attemptFirstFactorVerification
    prepareSecondFactorVerificationHandler = prepareSecondFactorVerification
    attemptSecondFactorVerificationHandler = attemptSecondFactorVerification
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

  @MainActor
  func startVerification(
    sessionId: String,
    params: Session.StartVerificationParams
  ) async throws -> SessionVerification {
    if let handler = startVerificationHandler {
      return try await handler(sessionId, params)
    }
    return .mockNeedsFirstFactor
  }

  @MainActor
  func prepareFirstFactorVerification(
    sessionId: String,
    params: Session.PrepareFirstFactorVerificationParams
  ) async throws -> SessionVerification {
    if let handler = prepareFirstFactorVerificationHandler {
      return try await handler(sessionId, params)
    }
    return .mockNeedsFirstFactor
  }

  @MainActor
  func attemptFirstFactorVerification(
    sessionId: String,
    params: Session.AttemptFirstFactorVerificationParams
  ) async throws -> SessionVerification {
    if let handler = attemptFirstFactorVerificationHandler {
      return try await handler(sessionId, params)
    }
    return .mockComplete
  }

  @MainActor
  func prepareSecondFactorVerification(
    sessionId: String,
    params: Session.PrepareSecondFactorVerificationParams
  ) async throws -> SessionVerification {
    if let handler = prepareSecondFactorVerificationHandler {
      return try await handler(sessionId, params)
    }
    return .mockNeedsSecondFactor
  }

  @MainActor
  func attemptSecondFactorVerification(
    sessionId: String,
    params: Session.AttemptSecondFactorVerificationParams
  ) async throws -> SessionVerification {
    if let handler = attemptSecondFactorVerificationHandler {
      return try await handler(sessionId, params)
    }
    return .mockComplete
  }
}
