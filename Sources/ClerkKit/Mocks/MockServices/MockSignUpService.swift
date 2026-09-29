//
//  MockSignUpService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

package final class MockSignUpService: SignUpServiceProtocol {
  nonisolated(unsafe) var createHandler: ((SignUp.CreateParams) async throws -> SignUp)?

  nonisolated(unsafe) var prepareVerificationHandler: ((String, SignUp.PrepareVerificationParams) async throws -> SignUp)?

  nonisolated(unsafe) var attemptVerificationHandler: ((String, SignUp.AttemptVerificationParams) async throws -> SignUp)?

  nonisolated(unsafe) var updateHandler: ((String, SignUp.UpdateParams) async throws -> SignUp)?

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
