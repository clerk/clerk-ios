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
    do {
      return try dependencies.keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    } catch {
      ClerkLogger.logError(error, message: "Failed to read device token from keychain")
      return nil
    }
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
  @_spi(FrameworkIntegration)
  public func updateDeviceToken(_ token: String) async throws {
    let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedToken.isEmpty else {
      throw DeviceTokenError.emptyToken
    }

    let previousToken = deviceToken
    try storeDeviceToken(normalizedToken)

    if previousToken != normalizedToken {
      clearCachedClientStateAfterDeviceTokenChange()
    }

    try await refreshClient(skipClientId: true)
  }

  /// Clears the stored Clerk device token and refreshes native auth state.
  ///
  /// This is intended for framework integrations that need to mirror another
  /// Clerk SDK runtime clearing its device token. The refresh intentionally
  /// omits the current client id so a stale anonymous client cannot conflict
  /// with the cleared device-token state.
  @_spi(FrameworkIntegration)
  public func clearDeviceToken() async throws {
    try deleteStoredDeviceToken()
    try markDeviceTokenClearPendingForWatchSync()
    clearCachedClientStateAfterDeviceTokenChange()
    syncWatchConnectivity()

    try await refreshClient(skipClientId: true, suppressDeviceTokenPersistence: true)
  }
}
