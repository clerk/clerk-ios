//
//  MockPhoneNumberService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

package final class MockPhoneNumberService: PhoneNumberServiceProtocol {
  package nonisolated(unsafe) var createHandler: ((String) async throws -> PhoneNumber)?

  package nonisolated(unsafe) var deleteHandler: ((String) async throws -> DeletedObject)?

  package nonisolated(unsafe) var prepareVerificationHandler: ((String) async throws -> PhoneNumber)?

  package nonisolated(unsafe) var attemptVerificationHandler: ((String, String) async throws -> PhoneNumber)?

  package nonisolated(unsafe) var makeDefaultSecondFactorHandler: ((String) async throws -> PhoneNumber)?

  package nonisolated(unsafe) var setReservedForSecondFactorHandler: ((String, Bool) async throws -> PhoneNumber)?

  package init(
    create: ((String) async throws -> PhoneNumber)? = nil,
    delete: ((String) async throws -> DeletedObject)? = nil,
    prepareVerification: ((String) async throws -> PhoneNumber)? = nil,
    attemptVerification: ((String, String) async throws -> PhoneNumber)? = nil,
    makeDefaultSecondFactor: ((String) async throws -> PhoneNumber)? = nil,
    setReservedForSecondFactor: ((String, Bool) async throws -> PhoneNumber)? = nil
  ) {
    createHandler = create
    deleteHandler = delete
    prepareVerificationHandler = prepareVerification
    attemptVerificationHandler = attemptVerification
    makeDefaultSecondFactorHandler = makeDefaultSecondFactor
    setReservedForSecondFactorHandler = setReservedForSecondFactor
  }

  @MainActor
  package func create(phoneNumber: String) async throws -> PhoneNumber {
    if let handler = createHandler {
      return try await handler(phoneNumber)
    }
    return .mock
  }

  @MainActor
  package func delete(phoneNumberId: String) async throws -> DeletedObject {
    if let handler = deleteHandler {
      return try await handler(phoneNumberId)
    }
    return .mock
  }

  @MainActor
  package func prepareVerification(phoneNumberId: String) async throws -> PhoneNumber {
    if let handler = prepareVerificationHandler {
      return try await handler(phoneNumberId)
    }
    return .mock
  }

  @MainActor
  package func attemptVerification(phoneNumberId: String, code: String) async throws -> PhoneNumber {
    if let handler = attemptVerificationHandler {
      return try await handler(phoneNumberId, code)
    }
    return .mock
  }

  @MainActor
  package func makeDefaultSecondFactor(phoneNumberId: String) async throws -> PhoneNumber {
    if let handler = makeDefaultSecondFactorHandler {
      return try await handler(phoneNumberId)
    }
    return .mock
  }

  @MainActor
  package func setReservedForSecondFactor(phoneNumberId: String, reserved: Bool) async throws -> PhoneNumber {
    if let handler = setReservedForSecondFactorHandler {
      return try await handler(phoneNumberId, reserved)
    }
    return .mock
  }
}
