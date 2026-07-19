//
//  Clerk+DeviceToken.swift
//  Clerk
//

import Foundation

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
    let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedToken.isEmpty else {
      throw DeviceTokenError.emptyToken
    }

    let result = try await identityController.updateDeviceToken(to: normalizedToken)
    guard result != .rejected else {
      throw DeviceTokenError.updateRejected
    }
    return try await refreshClient(skipClientId: true)
  }
}
