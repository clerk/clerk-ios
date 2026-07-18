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
      if let sharedSessionSyncCoordinator {
        return sharedSessionSyncCoordinator.currentDeviceToken
      }
      if dependencies.sharedSessionLocalIdentityStore != nil {
        return localIdentityDeviceToken
      }
      return try dependencies.identityKeychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
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

    let previousToken = deviceToken
    if previousToken != normalizedToken,
       let sharedSessionSyncCoordinator
    {
      try await sharedSessionSyncCoordinator.publishLocalIdentity(
        state: .cleared,
        deviceToken: normalizedToken,
        client: nil,
        serverDate: nil
      )
      return try await refreshClient(skipClientId: true)
    }

    if let localIdentityIO = dependencies.sharedSessionLocalIdentityIO {
      if previousToken != normalizedToken {
        let identity = try SharedSessionLocalIdentity(
          state: .cleared,
          deviceToken: normalizedToken,
          client: nil,
          serverDate: nil
        ).validated()
        let task = enqueueLocalIdentityOperation { [weak self] operationRevision in
          guard let self else { throw CancellationError() }
          return try await persistAndApplyAtomicLocalIdentity(
            identity,
            through: localIdentityIO,
            operationRevision: operationRevision,
            fenceAllClientResponses: false
          )
        }
        guard try await task.value else {
          throw CancellationError()
        }
      }
      return try await refreshClient(skipClientId: true)
    }

    if previousToken != normalizedToken {
      try dependencies.identityKeychain.set(
        normalizedToken,
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      )
      let wasApplyingSharedSessionIdentity = isApplyingSharedSessionIdentity
      isApplyingSharedSessionIdentity = true
      clearCachedClientStateAfterDeviceTokenChange()
      isApplyingSharedSessionIdentity = wasApplyingSharedSessionIdentity
      emitInternalStateChange(.sharedSessionIdentityDidChange)
    }

    return try await refreshClient(skipClientId: true)
  }
}
