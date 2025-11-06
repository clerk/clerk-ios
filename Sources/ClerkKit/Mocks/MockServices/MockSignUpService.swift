//
//  MockSignUpService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import AuthenticationServices
import Foundation

/// Mock implementation of `SignUpServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of service methods through handler closures.
/// All methods return default mock values if handlers are not provided.
public final class MockSignUpService: SignUpServiceProtocol {
  /// Custom handler for the `create(strategy:legalAccepted:locale:)` method.
  public nonisolated(unsafe) var createHandler: ((SignUp.CreateStrategy, Bool?, String?) async throws -> SignUp)?

  /// Custom handler for the `createWithParams(params:)` method.
  public nonisolated(unsafe) var createWithParamsHandler: ((any Encodable & Sendable) async throws -> SignUp)?

  /// Custom handler for the `update(signUpId:params:)` method.
  public nonisolated(unsafe) var updateHandler: ((String, SignUp.UpdateParams) async throws -> SignUp)?

  /// Custom handler for the `prepareVerification(signUpId:strategy:)` method.
  public nonisolated(unsafe) var prepareVerificationHandler: ((String, SignUp.PrepareStrategy) async throws -> SignUp)?

  /// Custom handler for the `attemptVerification(signUpId:strategy:)` method.
  public nonisolated(unsafe) var attemptVerificationHandler: ((String, SignUp.AttemptStrategy) async throws -> SignUp)?

  /// Custom handler for the `get(signUpId:rotatingTokenNonce:)` method.
  public nonisolated(unsafe) var getHandler: ((String, String?) async throws -> SignUp)?

  #if !os(tvOS) && !os(watchOS)
  /// Custom handler for the `authenticateWithRedirect(strategy:prefersEphemeralWebBrowserSession:)` method.
  public nonisolated(unsafe) var authenticateWithRedirectStrategyHandler: ((SignUp.AuthenticateWithRedirectStrategy, Bool) async throws -> TransferFlowResult)?

  /// Custom handler for the `authenticateWithRedirect(signUp:prefersEphemeralWebBrowserSession:)` method.
  public nonisolated(unsafe) var authenticateWithRedirectHandler: ((SignUp, Bool) async throws -> TransferFlowResult)?
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Custom handler for the `authenticateWithIdToken(provider:idToken:)` method.
  public nonisolated(unsafe) var authenticateWithIdTokenProviderHandler: ((IDTokenProvider, String) async throws -> TransferFlowResult)?

  /// Custom handler for the `authenticateWithIdToken(signUp:)` method.
  public nonisolated(unsafe) var authenticateWithIdTokenHandler: ((SignUp) async throws -> TransferFlowResult)?
  #endif

  public init(
    create: ((SignUp.CreateStrategy, Bool?, String?) async throws -> SignUp)? = nil,
    createWithParams: ((any Encodable & Sendable) async throws -> SignUp)? = nil,
    update: ((String, SignUp.UpdateParams) async throws -> SignUp)? = nil,
    prepareVerification: ((String, SignUp.PrepareStrategy) async throws -> SignUp)? = nil,
    attemptVerification: ((String, SignUp.AttemptStrategy) async throws -> SignUp)? = nil,
    get: ((String, String?) async throws -> SignUp)? = nil
  ) {
    createHandler = create
    createWithParamsHandler = createWithParams
    updateHandler = update
    prepareVerificationHandler = prepareVerification
    attemptVerificationHandler = attemptVerification
    getHandler = get
  }

  #if !os(tvOS) && !os(watchOS)
  public func setAuthenticateWithRedirect(_ handler: @escaping (SignUp.AuthenticateWithRedirectStrategy, Bool) async throws -> TransferFlowResult) {
    authenticateWithRedirectStrategyHandler = handler
  }

  public func setAuthenticateWithRedirect(_ handler: @escaping (SignUp, Bool) async throws -> TransferFlowResult) {
    authenticateWithRedirectHandler = handler
  }
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  public func setAuthenticateWithIdToken(_ handler: @escaping (IDTokenProvider, String) async throws -> TransferFlowResult) {
    authenticateWithIdTokenProviderHandler = handler
  }

  public func setAuthenticateWithIdToken(_ handler: @escaping (SignUp) async throws -> TransferFlowResult) {
    authenticateWithIdTokenHandler = handler
  }
  #endif

  @MainActor
  public func create(strategy: SignUp.CreateStrategy, legalAccepted: Bool?, locale: String?) async throws -> SignUp {
    if let handler = createHandler {
      return try await handler(strategy, legalAccepted, locale)
    }
    return .mock
  }

  @MainActor
  public func createWithParams(params: any Encodable & Sendable) async throws -> SignUp {
    if let handler = createWithParamsHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  public func update(signUpId: String, params: SignUp.UpdateParams) async throws -> SignUp {
    if let handler = updateHandler {
      return try await handler(signUpId, params)
    }
    return .mock
  }

  @MainActor
  public func prepareVerification(signUpId: String, strategy: SignUp.PrepareStrategy) async throws -> SignUp {
    if let handler = prepareVerificationHandler {
      return try await handler(signUpId, strategy)
    }
    return .mock
  }

  @MainActor
  public func attemptVerification(signUpId: String, strategy: SignUp.AttemptStrategy) async throws -> SignUp {
    if let handler = attemptVerificationHandler {
      return try await handler(signUpId, strategy)
    }
    return .mock
  }

  @MainActor
  public func get(signUpId: String, rotatingTokenNonce: String?) async throws -> SignUp {
    if let handler = getHandler {
      return try await handler(signUpId, rotatingTokenNonce)
    }
    return .mock
  }

  #if !os(tvOS) && !os(watchOS)
  @MainActor
  public func authenticateWithRedirect(strategy: SignUp.AuthenticateWithRedirectStrategy, prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult {
    if let handler = authenticateWithRedirectStrategyHandler {
      return try await handler(strategy, prefersEphemeralWebBrowserSession)
    }
    return .signUp(.mock)
  }

  @MainActor
  public func authenticateWithRedirect(signUp: SignUp, prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult {
    if let handler = authenticateWithRedirectHandler {
      return try await handler(signUp, prefersEphemeralWebBrowserSession)
    }
    return .signUp(.mock)
  }
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @MainActor
  public func authenticateWithIdToken(provider: IDTokenProvider, idToken: String) async throws -> TransferFlowResult {
    if let handler = authenticateWithIdTokenProviderHandler {
      return try await handler(provider, idToken)
    }
    return .signUp(.mock)
  }

  @MainActor
  public func authenticateWithIdToken(signUp: SignUp) async throws -> TransferFlowResult {
    if let handler = authenticateWithIdTokenHandler {
      return try await handler(signUp)
    }
    return .signUp(.mock)
  }
  #endif
}
