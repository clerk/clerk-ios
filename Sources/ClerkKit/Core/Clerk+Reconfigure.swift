//
//  Clerk+Reconfigure.swift
//  ClerkKit
//
//  Created for runtime reconfiguration support in demo apps.
//

import Foundation

@_spi(Internal)
public extension Clerk {
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
  static func reconfigure(publishableKey: String, options: ClerkOptions = .init()) throws {
    // 1. Clear keychain data
    clearAllKeychainItems()

    // 2. Cleanup managers
    shared.cleanupManagers()

    // 3. Clear in-memory state
    shared._auth = nil
    shared.client = nil
    shared.environment = nil
    shared.sessionsByUserId = [:]

    // 4. Re-run configuration
    try shared.performConfiguration(publishableKey: publishableKey, options: options)
  }
}
