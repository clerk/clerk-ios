//
//  MockPasskeyService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import AuthenticationServices
import Foundation

/// Mock implementation of `PasskeyServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of service methods through handler closures.
/// All methods return default mock values if handlers are not provided.
public final class MockPasskeyService: PasskeyServiceProtocol {
  /// Custom handler for the `create()` method.
  public nonisolated(unsafe) var createHandler: (() async throws -> Passkey)?

  /// Custom handler for the `update(passkeyId:name:)` method.
  public nonisolated(unsafe) var updateHandler: ((String, String) async throws -> Passkey)?

  /// Custom handler for the `attemptVerification(passkeyId:credential:)` method.
  public nonisolated(unsafe) var attemptVerificationHandler: ((String, String) async throws -> Passkey)?

  /// Custom handler for the `delete(passkeyId:)` method.
  public nonisolated(unsafe) var deleteHandler: ((String) async throws -> DeletedObject)?

  public init(
    create: (() async throws -> Passkey)? = nil,
    update: ((String, String) async throws -> Passkey)? = nil,
    attemptVerification: ((String, String) async throws -> Passkey)? = nil,
    delete: ((String) async throws -> DeletedObject)? = nil
  ) {
    self.createHandler = create
    self.updateHandler = update
    self.attemptVerificationHandler = attemptVerification
    self.deleteHandler = delete
  }

  @MainActor
  public func create() async throws -> Passkey {
    if let handler = createHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  public func update(passkeyId: String, name: String) async throws -> Passkey {
    if let handler = updateHandler {
      return try await handler(passkeyId, name)
    }
    return .mock
  }

  @MainActor
  public func attemptVerification(passkeyId: String, credential: String) async throws -> Passkey {
    if let handler = attemptVerificationHandler {
      return try await handler(passkeyId, credential)
    }
    return .mock
  }

  @MainActor
  public func delete(passkeyId: String) async throws -> DeletedObject {
    if let handler = deleteHandler {
      return try await handler(passkeyId)
    }
    return .mock
  }
}

