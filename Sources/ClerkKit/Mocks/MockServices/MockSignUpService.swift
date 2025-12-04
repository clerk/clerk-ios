//
//  MockSignUpService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Mock implementation of `SignUpServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of service methods through handler closures.
/// All methods return default mock values if handlers are not provided.
public final class MockSignUpService: SignUpServiceProtocol {
  /// Custom handler for the `create(params:)` method.
  nonisolated(unsafe) var createHandler: ((SignUp.CreateParams) async throws -> SignUp)?

  /// Custom handler for the `prepareVerification(signUpId:params:)` method.
  nonisolated(unsafe) var prepareVerificationHandler: ((String, SignUp.PrepareVerificationParams) async throws -> SignUp)?

  /// Custom handler for the `attemptVerification(signUpId:params:)` method.
  nonisolated(unsafe) var attemptVerificationHandler: ((String, SignUp.AttemptVerificationParams) async throws -> SignUp)?

  /// Custom handler for the `update(signUpId:params:)` method.
  nonisolated(unsafe) var updateHandler: ((String, SignUp.UpdateParams) async throws -> SignUp)?

  /// Custom handler for the `get(signUpId:params:)` method.
  nonisolated(unsafe) var getHandler: ((String, SignUp.GetParams) async throws -> SignUp)?

  init(
    create: ((SignUp.CreateParams) async throws -> SignUp)? = nil,
    prepareVerification: ((String, SignUp.PrepareVerificationParams) async throws -> SignUp)? = nil,
    attemptVerification: ((String, SignUp.AttemptVerificationParams) async throws -> SignUp)? = nil,
    update: ((String, SignUp.UpdateParams) async throws -> SignUp)? = nil,
    get: ((String, SignUp.GetParams) async throws -> SignUp)? = nil
  ) {
    createHandler = create
    prepareVerificationHandler = prepareVerification
    attemptVerificationHandler = attemptVerification
    updateHandler = update
    getHandler = get
  }

  @MainActor
  func create(params: SignUp.CreateParams) async throws -> SignUp {
    if let handler = createHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  func prepareVerification(signUpId: String, params: SignUp.PrepareVerificationParams) async throws -> SignUp {
    if let handler = prepareVerificationHandler {
      return try await handler(signUpId, params)
    }
    return .mock
  }

  @MainActor
  func attemptVerification(signUpId: String, params: SignUp.AttemptVerificationParams) async throws -> SignUp {
    if let handler = attemptVerificationHandler {
      return try await handler(signUpId, params)
    }
    return .mock
  }

  @MainActor
  func update(signUpId: String, params: SignUp.UpdateParams) async throws -> SignUp {
    if let handler = updateHandler {
      return try await handler(signUpId, params)
    }
    return .mock
  }

  @MainActor
  func get(signUpId: String, params: SignUp.GetParams) async throws -> SignUp {
    if let handler = getHandler {
      return try await handler(signUpId, params)
    }
    return .mock
  }
}
