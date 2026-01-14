//
//  MockSignInService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Mock implementation of `SignInServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of service methods through handler closures.
/// All methods return default mock values if handlers are not provided.
package final class MockSignInService: SignInServiceProtocol {
  /// Custom handler for the `create(params:)` method.
  nonisolated(unsafe) var createHandler: ((SignIn.CreateParams) async throws -> SignIn)?

  /// Custom handler for the `prepareFirstFactor(signInId:params:)` method.
  nonisolated(unsafe) var prepareFirstFactorHandler: ((String, SignIn.PrepareFirstFactorParams) async throws -> SignIn)?

  /// Custom handler for the `attemptFirstFactor(signInId:params:)` method.
  nonisolated(unsafe) var attemptFirstFactorHandler: ((String, SignIn.AttemptFirstFactorParams) async throws -> SignIn)?

  /// Custom handler for the `prepareSecondFactor(signInId:params:)` method.
  nonisolated(unsafe) var prepareSecondFactorHandler: ((String, SignIn.PrepareSecondFactorParams) async throws -> SignIn)?

  /// Custom handler for the `attemptSecondFactor(signInId:params:)` method.
  nonisolated(unsafe) var attemptSecondFactorHandler: ((String, SignIn.AttemptSecondFactorParams) async throws -> SignIn)?

  /// Custom handler for the `resetPassword(signInId:params:)` method.
  nonisolated(unsafe) var resetPasswordHandler: ((String, SignIn.ResetPasswordParams) async throws -> SignIn)?

  /// Custom handler for the `get(signInId:params:)` method.
  nonisolated(unsafe) var getHandler: ((String, SignIn.GetParams) async throws -> SignIn)?

  init(
    create: ((SignIn.CreateParams) async throws -> SignIn)? = nil,
    prepareFirstFactor: ((String, SignIn.PrepareFirstFactorParams) async throws -> SignIn)? = nil,
    attemptFirstFactor: ((String, SignIn.AttemptFirstFactorParams) async throws -> SignIn)? = nil,
    prepareSecondFactor: ((String, SignIn.PrepareSecondFactorParams) async throws -> SignIn)? = nil,
    attemptSecondFactor: ((String, SignIn.AttemptSecondFactorParams) async throws -> SignIn)? = nil,
    resetPassword: ((String, SignIn.ResetPasswordParams) async throws -> SignIn)? = nil,
    get: ((String, SignIn.GetParams) async throws -> SignIn)? = nil
  ) {
    createHandler = create
    prepareFirstFactorHandler = prepareFirstFactor
    attemptFirstFactorHandler = attemptFirstFactor
    prepareSecondFactorHandler = prepareSecondFactor
    attemptSecondFactorHandler = attemptSecondFactor
    resetPasswordHandler = resetPassword
    getHandler = get
  }

  @MainActor
  func create(params: SignIn.CreateParams) async throws -> SignIn {
    if let handler = createHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  func prepareFirstFactor(signInId: String, params: SignIn.PrepareFirstFactorParams) async throws -> SignIn {
    if let handler = prepareFirstFactorHandler {
      return try await handler(signInId, params)
    }
    return .mock
  }

  @MainActor
  func attemptFirstFactor(signInId: String, params: SignIn.AttemptFirstFactorParams) async throws -> SignIn {
    if let handler = attemptFirstFactorHandler {
      return try await handler(signInId, params)
    }
    return .mock
  }

  @MainActor
  func prepareSecondFactor(signInId: String, params: SignIn.PrepareSecondFactorParams) async throws -> SignIn {
    if let handler = prepareSecondFactorHandler {
      return try await handler(signInId, params)
    }
    return .mock
  }

  @MainActor
  func attemptSecondFactor(signInId: String, params: SignIn.AttemptSecondFactorParams) async throws -> SignIn {
    if let handler = attemptSecondFactorHandler {
      return try await handler(signInId, params)
    }
    return .mock
  }

  @MainActor
  func resetPassword(signInId: String, params: SignIn.ResetPasswordParams) async throws -> SignIn {
    if let handler = resetPasswordHandler {
      return try await handler(signInId, params)
    }
    return .mock
  }

  @MainActor
  func get(signInId: String, params: SignIn.GetParams) async throws -> SignIn {
    if let handler = getHandler {
      return try await handler(signInId, params)
    }
    return .mock
  }
}
