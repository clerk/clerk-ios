//
//  MockEmailAddressService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

package final class MockEmailAddressService: EmailAddressServiceProtocol {
  package nonisolated(unsafe) var createHandler: ((String) async throws -> EmailAddress)?

  package nonisolated(unsafe) var prepareVerificationHandler: ((String, EmailAddress.PrepareStrategy) async throws -> EmailAddress)?

  package nonisolated(unsafe) var attemptVerificationHandler: ((String, EmailAddress.AttemptStrategy) async throws -> EmailAddress)?

  package nonisolated(unsafe) var destroyHandler: ((String) async throws -> DeletedObject)?

  package init(
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
  package func create(email: String) async throws -> EmailAddress {
    if let handler = createHandler {
      return try await handler(email)
    }
    return .mock
  }

  @MainActor
  package func prepareVerification(emailAddressId: String, strategy: EmailAddress.PrepareStrategy) async throws -> EmailAddress {
    if let handler = prepareVerificationHandler {
      return try await handler(emailAddressId, strategy)
    }
    return .mock
  }

  @MainActor
  package func attemptVerification(emailAddressId: String, strategy: EmailAddress.AttemptStrategy) async throws -> EmailAddress {
    if let handler = attemptVerificationHandler {
      return try await handler(emailAddressId, strategy)
    }
    return .mock
  }

  @MainActor
  package func destroy(emailAddressId: String) async throws -> DeletedObject {
    if let handler = destroyHandler {
      return try await handler(emailAddressId)
    }
    return .mock
  }
}
