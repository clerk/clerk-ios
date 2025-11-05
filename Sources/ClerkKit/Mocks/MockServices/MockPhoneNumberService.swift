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
public final class MockPhoneNumberService: PhoneNumberServiceProtocol {
  /// Custom handler for the `create(phoneNumber:)` method.
  public nonisolated(unsafe) var createHandler: ((String) async throws -> PhoneNumber)?

  /// Custom handler for the `delete(phoneNumberId:)` method.
  public nonisolated(unsafe) var deleteHandler: ((String) async throws -> DeletedObject)?

  /// Custom handler for the `prepareVerification(phoneNumberId:)` method.
  public nonisolated(unsafe) var prepareVerificationHandler: ((String) async throws -> PhoneNumber)?

  /// Custom handler for the `attemptVerification(phoneNumberId:code:)` method.
  public nonisolated(unsafe) var attemptVerificationHandler: ((String, String) async throws -> PhoneNumber)?

  /// Custom handler for the `makeDefaultSecondFactor(phoneNumberId:)` method.
  public nonisolated(unsafe) var makeDefaultSecondFactorHandler: ((String) async throws -> PhoneNumber)?

  /// Custom handler for the `setReservedForSecondFactor(phoneNumberId:reserved:)` method.
  public nonisolated(unsafe) var setReservedForSecondFactorHandler: ((String, Bool) async throws -> PhoneNumber)?

  public init(
    create: ((String) async throws -> PhoneNumber)? = nil,
    delete: ((String) async throws -> DeletedObject)? = nil,
    prepareVerification: ((String) async throws -> PhoneNumber)? = nil,
    attemptVerification: ((String, String) async throws -> PhoneNumber)? = nil,
    makeDefaultSecondFactor: ((String) async throws -> PhoneNumber)? = nil,
    setReservedForSecondFactor: ((String, Bool) async throws -> PhoneNumber)? = nil
  ) {
    self.createHandler = create
    self.deleteHandler = delete
    self.prepareVerificationHandler = prepareVerification
    self.attemptVerificationHandler = attemptVerification
    self.makeDefaultSecondFactorHandler = makeDefaultSecondFactor
    self.setReservedForSecondFactorHandler = setReservedForSecondFactor
  }

  @MainActor
  public func create(phoneNumber: String) async throws -> PhoneNumber {
    if let handler = createHandler {
      return try await handler(phoneNumber)
    }
    return .mock
  }

  @MainActor
  public func delete(phoneNumberId: String) async throws -> DeletedObject {
    if let handler = deleteHandler {
      return try await handler(phoneNumberId)
    }
    return .mock
  }

  @MainActor
  public func prepareVerification(phoneNumberId: String) async throws -> PhoneNumber {
    if let handler = prepareVerificationHandler {
      return try await handler(phoneNumberId)
    }
    return .mock
  }

  @MainActor
  public func attemptVerification(phoneNumberId: String, code: String) async throws -> PhoneNumber {
    if let handler = attemptVerificationHandler {
      return try await handler(phoneNumberId, code)
    }
    return .mock
  }

  @MainActor
  public func makeDefaultSecondFactor(phoneNumberId: String) async throws -> PhoneNumber {
    if let handler = makeDefaultSecondFactorHandler {
      return try await handler(phoneNumberId)
    }
    return .mock
  }

  @MainActor
  public func setReservedForSecondFactor(phoneNumberId: String, reserved: Bool) async throws -> PhoneNumber {
    if let handler = setReservedForSecondFactorHandler {
      return try await handler(phoneNumberId, reserved)
    }
    return .mock
  }
}

