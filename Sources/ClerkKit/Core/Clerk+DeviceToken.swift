//
//  Clerk+DeviceToken.swift
//  Clerk
//

import Foundation

extension Clerk {
  @_spi(FrameworkIntegration) public enum DeviceTokenError: Error, LocalizedError {
    case emptyToken

    public var errorDescription: String? {
      switch self {
      case .emptyToken:
        "Device token must not be empty."
      }
    }
  }

  /// The currently stored Clerk device token, if one is available.
  @_spi(FrameworkIntegration)
  public var deviceToken: String? {
    if let sharedSessionSyncCoordinator {
      return sharedSessionSyncCoordinator.deviceToken
    }

    do {
      return try dependencies.identityKeychain.string(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      )
    } catch {
      ClerkLogger.logError(error, message: "Failed to read device token from keychain")
      return nil
    }
  }

  func storeDeviceToken(_ token: String) throws {
    let previousToken = deviceToken
    let currentToken = try replaceStoredDeviceToken(token)
    emitInternalStateChange(.deviceTokenDidChange(previous: previousToken, current: currentToken))
  }

  @discardableResult
  func replaceStoredDeviceToken(_ token: String?) throws -> String? {
    let normalizedToken = token.nilIfEmpty
    if let normalizedToken {
      try dependencies.identityKeychain.set(
        normalizedToken,
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      )
    } else {
      try dependencies.identityKeychain.deleteItem(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      )
    }

    sharedSessionSyncCoordinator?.updateDeviceToken(normalizedToken)
    return normalizedToken
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
    let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedToken.isEmpty else {
      throw DeviceTokenError.emptyToken
    }

    let previousToken = deviceToken
    try storeDeviceToken(normalizedToken)

    if previousToken != normalizedToken {
      clearCachedClientStateAfterDeviceTokenChange()
    }

    return try await refreshClient(skipClientId: true)
  }
}
