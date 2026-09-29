//
//  MockPasskeyService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import AuthenticationServices
import Foundation

package final class MockPasskeyService: PasskeyServiceProtocol {
  package nonisolated(unsafe) var createHandler: (() async throws -> Passkey)?

  package nonisolated(unsafe) var updateHandler: ((String, String) async throws -> Passkey)?

  package nonisolated(unsafe) var attemptVerificationHandler: ((String, String) async throws -> Passkey)?

  package nonisolated(unsafe) var deleteHandler: ((String) async throws -> DeletedObject)?

  package init(
    create: (() async throws -> Passkey)? = nil,
    update: ((String, String) async throws -> Passkey)? = nil,
    attemptVerification: ((String, String) async throws -> Passkey)? = nil,
    delete: ((String) async throws -> DeletedObject)? = nil
  ) {
    createHandler = create
    updateHandler = update
    attemptVerificationHandler = attemptVerification
    deleteHandler = delete
  }

  @MainActor
  package func create() async throws -> Passkey {
    if let handler = createHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  package func update(passkeyId: String, name: String) async throws -> Passkey {
    if let handler = updateHandler {
      return try await handler(passkeyId, name)
    }
    return .mock
  }

  @MainActor
  package func attemptVerification(passkeyId: String, credential: String) async throws -> Passkey {
    if let handler = attemptVerificationHandler {
      return try await handler(passkeyId, credential)
    }
    return .mock
  }

  @MainActor
  package func delete(passkeyId: String) async throws -> DeletedObject {
    if let handler = deleteHandler {
      return try await handler(passkeyId)
    }
    return .mock
  }
}
