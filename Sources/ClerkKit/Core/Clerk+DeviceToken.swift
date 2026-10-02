//
//  Clerk+DeviceToken.swift
//  Clerk
//

import Foundation

extension ClerkIdentityController {
  enum DeviceTokenTransitionResult: Equatable {
    case applied
    case unchanged
    case rejected
  }
}

extension Clerk {
  @_spi(FrameworkIntegration) public enum DeviceTokenError: Error, LocalizedError {
    case emptyToken
    case updateRejected

    public var errorDescription: String? {
      switch self {
      case .emptyToken:
        "Device token must not be empty."
      case .updateRejected:
        "The device token update lost shared identity reconciliation and was not applied."
      }
    }
  }

  /// The currently stored Clerk device token, if one is available.
  @_spi(FrameworkIntegration)
  public var deviceToken: String? {
    identityController.currentDeviceToken
  }

  /// Updates the stored Clerk device token and refreshes native auth state.
  ///
  /// This is intended for framework integrations that need to hand a client token
  /// from another Clerk SDK runtime to ClerkKit. The refresh intentionally omits
  /// the current client id so a stale anonymous client cannot conflict with the
  /// newly supplied device token.
  ///
  /// - Parameter token: The Clerk device token to store in ClerkKit's keychain.
  ///   Empty or whitespace-only values are rejected.
  /// - Returns: The refreshed client resolved from the stored device token, or
  ///   `nil` when no client is available.
  @_spi(FrameworkIntegration)
  @discardableResult
  public func updateDeviceToken(_ token: String) async throws -> Client? {
    try runtimeScope.validateStableRuntime()
    guard let normalizedToken = Optional(token).nilIfEmpty else {
      throw DeviceTokenError.emptyToken
    }

    let result = try identityController.adoptDeviceToken(normalizedToken)
    guard result != .rejected else {
      throw DeviceTokenError.updateRejected
    }
    return try await refreshClient(skipClientId: true)
  }

  /// Replaces the stored Clerk device token only if it still matches `expected`.
  ///
  /// This is intended for framework integrations where another Clerk SDK runtime
  /// shares ClerkKit's client and writes back device tokens rotated by its own
  /// requests. No request is made and the current client is kept; clearing the
  /// token also clears the client.
  ///
  /// - Parameters:
  ///   - token: The Clerk device token to store, or `nil` to clear it. Empty or
  ///     whitespace-only values are rejected.
  ///   - expected: The device token the caller's request was sent with, or `nil`
  ///     if it was sent without one.
  /// - Returns: `true` if the stored device token is now `token`, or `false` if
  ///   the stored device token no longer matched `expected` and was left unchanged.
  @_spi(FrameworkIntegration)
  @discardableResult
  public func setDeviceToken(_ token: String?, expected: String?) async throws -> Bool {
    try runtimeScope.validateStableRuntime()
    let normalizedToken = token.nilIfEmpty
    guard token == nil || normalizedToken != nil else {
      throw DeviceTokenError.emptyToken
    }

    return try await identityController.compareAndSetDeviceToken(
      normalizedToken,
      expected: expected.nilIfEmpty
    )
  }
}
