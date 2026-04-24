//
//  MockPhoneNumberService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Mock implementation of `PhoneNumberServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of service methods through handler closures.
/// All methods return default mock values if handlers are not provided.
package final class MockPhoneNumberService: PhoneNumberServiceProtocol {
  /// Custom handler for the `create(phoneNumber:sessionId:)` method.
  package nonisolated(unsafe) var createHandler: ((String, String?) async throws -> PhoneNumber)?

  /// Custom handler for the `delete(phoneNumberId:sessionId:)` method.
  package nonisolated(unsafe) var deleteHandler: ((String, String?) async throws -> DeletedObject)?

  /// Custom handler for the `prepareVerification(phoneNumberId:sessionId:)` method.
  package nonisolated(unsafe) var prepareVerificationHandler: ((String, String?) async throws -> PhoneNumber)?

  /// Custom handler for the `attemptVerification(phoneNumberId:code:sessionId:)` method.
  package nonisolated(unsafe) var attemptVerificationHandler: ((String, String, String?) async throws -> PhoneNumber)?

  /// Custom handler for the `makeDefaultSecondFactor(phoneNumberId:sessionId:)` method.
  package nonisolated(unsafe) var makeDefaultSecondFactorHandler: ((String, String?) async throws -> PhoneNumber)?

  /// Custom handler for the `setReservedForSecondFactor(phoneNumberId:reserved:sessionId:)` method.
  package nonisolated(unsafe) var setReservedForSecondFactorHandler: ((String, Bool, String?) async throws -> PhoneNumber)?

  package init(
    create: ((String, String?) async throws -> PhoneNumber)? = nil,
    delete: ((String, String?) async throws -> DeletedObject)? = nil,
    prepareVerification: ((String, String?) async throws -> PhoneNumber)? = nil,
    attemptVerification: ((String, String, String?) async throws -> PhoneNumber)? = nil,
    makeDefaultSecondFactor: ((String, String?) async throws -> PhoneNumber)? = nil,
    setReservedForSecondFactor: ((String, Bool, String?) async throws -> PhoneNumber)? = nil
  ) {
    createHandler = create
    deleteHandler = delete
    prepareVerificationHandler = prepareVerification
    attemptVerificationHandler = attemptVerification
    makeDefaultSecondFactorHandler = makeDefaultSecondFactor
    setReservedForSecondFactorHandler = setReservedForSecondFactor
  }

  @MainActor
  package func create(phoneNumber: String, sessionId: String?) async throws -> PhoneNumber {
    if let handler = createHandler {
      return try await handler(phoneNumber, sessionId)
    }
    return .mock
  }

  @MainActor
  package func delete(phoneNumberId: String, sessionId: String?) async throws -> DeletedObject {
    if let handler = deleteHandler {
      return try await handler(phoneNumberId, sessionId)
    }
    return .mock
  }

  @MainActor
  package func prepareVerification(phoneNumberId: String, sessionId: String?) async throws -> PhoneNumber {
    if let handler = prepareVerificationHandler {
      return try await handler(phoneNumberId, sessionId)
    }
    return .mock
  }

  @MainActor
  package func attemptVerification(phoneNumberId: String, code: String, sessionId: String?) async throws -> PhoneNumber {
    if let handler = attemptVerificationHandler {
      return try await handler(phoneNumberId, code, sessionId)
    }
    return .mock
  }

  @MainActor
  package func makeDefaultSecondFactor(phoneNumberId: String, sessionId: String?) async throws -> PhoneNumber {
    if let handler = makeDefaultSecondFactorHandler {
      return try await handler(phoneNumberId, sessionId)
    }
    return .mock
  }

  @MainActor
  package func setReservedForSecondFactor(phoneNumberId: String, reserved: Bool, sessionId: String?) async throws -> PhoneNumber {
    if let handler = setReservedForSecondFactorHandler {
      return try await handler(phoneNumberId, reserved, sessionId)
    }
    return .mock
  }
}
