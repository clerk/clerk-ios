//
//  MockEmailAddressService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Mock implementation of `EmailAddressServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of service methods through handler closures.
/// All methods return default mock values if handlers are not provided.
public final class MockEmailAddressService: EmailAddressServiceProtocol {
  /// Custom handler for the `create(email:)` method.
  public nonisolated(unsafe) var createHandler: ((String) async throws -> EmailAddress)?

  /// Custom handler for the `prepareVerification(emailAddressId:strategy:)` method.
  public nonisolated(unsafe) var prepareVerificationHandler: ((String, EmailAddress.PrepareStrategy) async throws -> EmailAddress)?

  /// Custom handler for the `attemptVerification(emailAddressId:strategy:)` method.
  public nonisolated(unsafe) var attemptVerificationHandler: ((String, EmailAddress.AttemptStrategy) async throws -> EmailAddress)?

  /// Custom handler for the `destroy(emailAddressId:)` method.
  public nonisolated(unsafe) var destroyHandler: ((String) async throws -> DeletedObject)?

  public init(
    create: ((String) async throws -> EmailAddress)? = nil,
    prepareVerification: ((String, EmailAddress.PrepareStrategy) async throws -> EmailAddress)? = nil,
    attemptVerification: ((String, EmailAddress.AttemptStrategy) async throws -> EmailAddress)? = nil,
    destroy: ((String) async throws -> DeletedObject)? = nil
  ) {
    createHandler = create
    prepareVerificationHandler = prepareVerification
    attemptVerificationHandler = attemptVerification
    destroyHandler = destroy
  }

  @MainActor
  public func create(email: String) async throws -> EmailAddress {
    if let handler = createHandler {
      return try await handler(email)
    }
    return .mock
  }

  @MainActor
  public func prepareVerification(emailAddressId: String, strategy: EmailAddress.PrepareStrategy) async throws -> EmailAddress {
    if let handler = prepareVerificationHandler {
      return try await handler(emailAddressId, strategy)
    }
    return .mock
  }

  @MainActor
  public func attemptVerification(emailAddressId: String, strategy: EmailAddress.AttemptStrategy) async throws -> EmailAddress {
    if let handler = attemptVerificationHandler {
      return try await handler(emailAddressId, strategy)
    }
    return .mock
  }

  @MainActor
  public func destroy(emailAddressId: String) async throws -> DeletedObject {
    if let handler = destroyHandler {
      return try await handler(emailAddressId)
    }
    return .mock
  }
}
