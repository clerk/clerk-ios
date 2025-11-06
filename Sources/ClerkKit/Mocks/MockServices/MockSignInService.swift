//
//  MockSignInService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import AuthenticationServices
import Foundation

/// Mock implementation of `SignInServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of service methods through handler closures.
/// All methods return default mock values if handlers are not provided.
public final class MockSignInService: SignInServiceProtocol {
  /// Custom handler for the `create(strategy:locale:)` method.
  public nonisolated(unsafe) var createHandler: ((SignIn.CreateStrategy, String?) async throws -> SignIn)?

  /// Custom handler for the `createWithParams(params:)` method.
  public nonisolated(unsafe) var createWithParamsHandler: ((any Encodable & Sendable) async throws -> SignIn)?

  /// Custom handler for the `resetPassword(signInId:params:)` method.
  public nonisolated(unsafe) var resetPasswordHandler: ((String, SignIn.ResetPasswordParams) async throws -> SignIn)?

  /// Custom handler for the `prepareFirstFactor(signInId:strategy:signIn:)` method.
  public nonisolated(unsafe) var prepareFirstFactorHandler: ((String, SignIn.PrepareFirstFactorStrategy, SignIn) async throws -> SignIn)?

  /// Custom handler for the `attemptFirstFactor(signInId:strategy:)` method.
  public nonisolated(unsafe) var attemptFirstFactorHandler: ((String, SignIn.AttemptFirstFactorStrategy) async throws -> SignIn)?

  /// Custom handler for the `prepareSecondFactor(signInId:strategy:)` method.
  public nonisolated(unsafe) var prepareSecondFactorHandler: ((String, SignIn.PrepareSecondFactorStrategy) async throws -> SignIn)?

  /// Custom handler for the `attemptSecondFactor(signInId:strategy:)` method.
  public nonisolated(unsafe) var attemptSecondFactorHandler: ((String, SignIn.AttemptSecondFactorStrategy) async throws -> SignIn)?

  /// Custom handler for the `get(signInId:rotatingTokenNonce:)` method.
  public nonisolated(unsafe) var getHandler: ((String, String?) async throws -> SignIn)?

  #if !os(tvOS) && !os(watchOS)
  /// Custom handler for the `authenticateWithRedirect(strategy:prefersEphemeralWebBrowserSession:)` method.
  public nonisolated(unsafe) var authenticateWithRedirectStrategyHandler: ((SignIn.AuthenticateWithRedirectStrategy, Bool) async throws -> TransferFlowResult)?

  /// Custom handler for the `authenticateWithRedirect(signIn:prefersEphemeralWebBrowserSession:)` method.
  public nonisolated(unsafe) var authenticateWithRedirectHandler: ((SignIn, Bool) async throws -> TransferFlowResult)?
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Custom handler for the `getCredentialForPasskey(signIn:autofill:preferImmediatelyAvailableCredentials:)` method.
  public nonisolated(unsafe) var getCredentialForPasskeyHandler: ((SignIn, Bool, Bool) async throws -> String)?

  /// Custom handler for the `authenticateWithIdToken(provider:idToken:)` method.
  public nonisolated(unsafe) var authenticateWithIdTokenProviderHandler: ((IDTokenProvider, String) async throws -> TransferFlowResult)?

  /// Custom handler for the `authenticateWithIdToken(signIn:)` method.
  public nonisolated(unsafe) var authenticateWithIdTokenHandler: ((SignIn) async throws -> TransferFlowResult)?
  #endif

  public init(
    create: ((SignIn.CreateStrategy, String?) async throws -> SignIn)? = nil,
    createWithParams: ((any Encodable & Sendable) async throws -> SignIn)? = nil,
    resetPassword: ((String, SignIn.ResetPasswordParams) async throws -> SignIn)? = nil,
    prepareFirstFactor: ((String, SignIn.PrepareFirstFactorStrategy, SignIn) async throws -> SignIn)? = nil,
    attemptFirstFactor: ((String, SignIn.AttemptFirstFactorStrategy) async throws -> SignIn)? = nil,
    prepareSecondFactor: ((String, SignIn.PrepareSecondFactorStrategy) async throws -> SignIn)? = nil,
    attemptSecondFactor: ((String, SignIn.AttemptSecondFactorStrategy) async throws -> SignIn)? = nil,
    get: ((String, String?) async throws -> SignIn)? = nil
  ) {
    createHandler = create
    createWithParamsHandler = createWithParams
    resetPasswordHandler = resetPassword
    prepareFirstFactorHandler = prepareFirstFactor
    attemptFirstFactorHandler = attemptFirstFactor
    prepareSecondFactorHandler = prepareSecondFactor
    attemptSecondFactorHandler = attemptSecondFactor
    getHandler = get
  }

  #if !os(tvOS) && !os(watchOS)
  public func setAuthenticateWithRedirect(_ handler: @escaping (SignIn.AuthenticateWithRedirectStrategy, Bool) async throws -> TransferFlowResult) {
    authenticateWithRedirectStrategyHandler = handler
  }

  public func setAuthenticateWithRedirect(_ handler: @escaping (SignIn, Bool) async throws -> TransferFlowResult) {
    authenticateWithRedirectHandler = handler
  }
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  public func setGetCredentialForPasskey(_ handler: @escaping (SignIn, Bool, Bool) async throws -> String) {
    getCredentialForPasskeyHandler = handler
  }

  public func setAuthenticateWithIdToken(_ handler: @escaping (IDTokenProvider, String) async throws -> TransferFlowResult) {
    authenticateWithIdTokenProviderHandler = handler
  }

  public func setAuthenticateWithIdToken(_ handler: @escaping (SignIn) async throws -> TransferFlowResult) {
    authenticateWithIdTokenHandler = handler
  }
  #endif

  @MainActor
  public func create(strategy: SignIn.CreateStrategy, locale: String?) async throws -> SignIn {
    if let handler = createHandler {
      return try await handler(strategy, locale)
    }
    return .mock
  }

  @MainActor
  public func createWithParams(params: any Encodable & Sendable) async throws -> SignIn {
    if let handler = createWithParamsHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  public func resetPassword(signInId: String, params: SignIn.ResetPasswordParams) async throws -> SignIn {
    if let handler = resetPasswordHandler {
      return try await handler(signInId, params)
    }
    return .mock
  }

  @MainActor
  public func prepareFirstFactor(signInId: String, strategy: SignIn.PrepareFirstFactorStrategy, signIn: SignIn) async throws -> SignIn {
    if let handler = prepareFirstFactorHandler {
      return try await handler(signInId, strategy, signIn)
    }
    return .mock
  }

  @MainActor
  public func attemptFirstFactor(signInId: String, strategy: SignIn.AttemptFirstFactorStrategy) async throws -> SignIn {
    if let handler = attemptFirstFactorHandler {
      return try await handler(signInId, strategy)
    }
    return .mock
  }

  @MainActor
  public func prepareSecondFactor(signInId: String, strategy: SignIn.PrepareSecondFactorStrategy) async throws -> SignIn {
    if let handler = prepareSecondFactorHandler {
      return try await handler(signInId, strategy)
    }
    return .mock
  }

  @MainActor
  public func attemptSecondFactor(signInId: String, strategy: SignIn.AttemptSecondFactorStrategy) async throws -> SignIn {
    if let handler = attemptSecondFactorHandler {
      return try await handler(signInId, strategy)
    }
    return .mock
  }

  @MainActor
  public func get(signInId: String, rotatingTokenNonce: String?) async throws -> SignIn {
    if let handler = getHandler {
      return try await handler(signInId, rotatingTokenNonce)
    }
    return .mock
  }

  #if !os(tvOS) && !os(watchOS)
  @MainActor
  public func authenticateWithRedirect(strategy: SignIn.AuthenticateWithRedirectStrategy, prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult {
    if let handler = authenticateWithRedirectStrategyHandler {
      return try await handler(strategy, prefersEphemeralWebBrowserSession)
    }
    return .signIn(.mock)
  }

  @MainActor
  public func authenticateWithRedirect(signIn: SignIn, prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult {
    if let handler = authenticateWithRedirectHandler {
      return try await handler(signIn, prefersEphemeralWebBrowserSession)
    }
    return .signIn(.mock)
  }
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @MainActor
  public func getCredentialForPasskey(signIn: SignIn, autofill: Bool, preferImmediatelyAvailableCredentials: Bool) async throws -> String {
    if let handler = getCredentialForPasskeyHandler {
      return try await handler(signIn, autofill, preferImmediatelyAvailableCredentials)
    }
    return "mock-credential"
  }

  @MainActor
  public func authenticateWithIdToken(provider: IDTokenProvider, idToken: String) async throws -> TransferFlowResult {
    if let handler = authenticateWithIdTokenProviderHandler {
      return try await handler(provider, idToken)
    }
    return .signIn(.mock)
  }

  @MainActor
  public func authenticateWithIdToken(signIn: SignIn) async throws -> TransferFlowResult {
    if let handler = authenticateWithIdTokenHandler {
      return try await handler(signIn)
    }
    return .signIn(.mock)
  }
  #endif
}
