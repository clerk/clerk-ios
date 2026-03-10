//
//  Clerk+Reconfigure.swift
//  ClerkKit
//
//  Created for runtime reconfiguration support in demo apps.
//

import Foundation

@_spi(Internal)
extension Clerk {
  /// Reconfigures the shared Clerk instance with a new publishable key.
  ///
  /// This method clears all existing state (keychain data, in-memory state, and managers)
  /// and reinitializes Clerk with the new configuration.
  ///
  /// - Warning: This API is intended for demo and testing purposes only.
  ///   It is not recommended for production use.
  ///
  /// - Parameters:
  ///   - publishableKey: The new publishable key from your Clerk Dashboard.
  ///   - options: Configuration options for the Clerk instance.
  /// - Throws: An error if reconfiguration fails.
  @MainActor
  public static func reconfigure(publishableKey: String, options: Clerk.Options = .init()) async throws {
    // 1. Cleanup managers
    await shared.cleanupManagersAndDrainCache()

    // 2. Clear keychain data after persistence work has fully drained.
    clearAllKeychainItems()

    // 3. Clear in-memory state
    shared.client = nil
    shared.environment = nil
    shared.sessionsByUserId = [:]

    // 4. Re-run configuration
    try shared.performConfiguration(publishableKey: publishableKey, options: options)
  }
}
