//
//  CacheManager.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Protocol defining callbacks for cache loading operations.
///
/// This allows the cache manager to interact with Clerk instance properties
/// without directly coupling to the Clerk class.
protocol CacheCoordinator: AnyObject, Sendable {
  /// Sets the client if no client is currently set.
  ///
  /// - Parameter client: The client to set, or nil to clear.
  @MainActor func setClientIfNeeded(_ client: Client?)

  /// Sets the environment if the current environment is empty.
  ///
  /// - Parameter environment: The environment to set.
  @MainActor func setEnvironmentIfNeeded(_ environment: Clerk.Environment)

  /// Returns whether a client is currently set.
  @MainActor var hasClient: Bool { get }

  /// Returns whether the current environment is empty.
  @MainActor var isEnvironmentEmpty: Bool { get }
}

/// Manages caching of Clerk client and environment data to keychain.
///
/// This class handles loading and saving cached data, coordinating with the Clerk instance
/// to ensure cached data doesn't overwrite fresh data loaded from the API.
@MainActor
final class CacheManager {
  /// The coordinator that manages the actual property updates.
  private weak var coordinator: (any CacheCoordinator)?

  /// The keychain storage for persisting cached data.
  private let keychain: any KeychainStorage

  /// Creates a new cache manager.
  ///
  /// - Parameters:
  ///   - coordinator: The object that coordinates cache updates with Clerk properties.
  ///   - keychain: The keychain storage for persisting cached data.
  init(coordinator: any CacheCoordinator, keychain: any KeychainStorage) {
    self.coordinator = coordinator
    self.keychain = keychain
  }

  /// Loads cached client and environment data from keychain.
  ///
  /// This method loads both cached client and environment if they exist and if
  /// the current state allows them to be set (i.e., no fresh data exists).
  ///
  /// Errors are logged but do not prevent initialization from proceeding.
  func loadCachedData() async {
    await loadCachedClient()
    await loadCachedEnvironment()
  }

  /// Loads cached client data from keychain if available.
  ///
  /// The cached client is only set if no client is currently set, preventing
  /// cached data from overwriting fresh data loaded from the API.
  private func loadCachedClient() async {
    do {
      guard let cachedClient = try loadClientFromKeychain() else {
        return
      }

      // Only set cached client if we don't already have one
      // This prevents overwriting fresh data during load()
      guard let coordinator else { return }
      if coordinator.hasClient == false {
        coordinator.setClientIfNeeded(cachedClient)
      }
    } catch {
      // Log keychain errors but don't fail initialization - cached data is optional
      ClerkLogger.logError(
        error,
        message: "Failed to load cached client from keychain. This is non-critical and initialization will continue."
      )
    }
  }

  /// Loads cached environment data from keychain if available.
  ///
  /// The cached environment is only set if the current environment is empty, preventing
  /// cached data from overwriting fresh data loaded from the API.
  private func loadCachedEnvironment() async {
    do {
      guard let cachedEnvironment = try loadEnvironmentFromKeychain() else {
        return
      }

      // Only set cached environment if we don't already have fresh data
      // This prevents overwriting fresh data during load()
      guard let coordinator else { return }
      if coordinator.isEnvironmentEmpty == true {
        coordinator.setEnvironmentIfNeeded(cachedEnvironment)
      }
    } catch {
      // Log keychain errors but don't fail initialization - cached data is optional
      ClerkLogger.logError(
        error,
        message: "Failed to load cached environment from keychain. This is non-critical and initialization will continue."
      )
    }
  }

  /// Saves client data to keychain.
  ///
  /// - Parameter client: The client to save.
  func saveClient(_ client: Client) {
    do {
      try saveClientToKeychain(client)
    } catch {
      // Log keychain errors but don't fail - saving is best-effort
      ClerkLogger.logError(
        error,
        message: "Failed to save client to keychain. This is non-critical but may affect offline functionality."
      )
    }
  }

  /// Saves environment data to keychain.
  ///
  /// - Parameter environment: The environment to save.
  func saveEnvironment(_ environment: Clerk.Environment) {
    do {
      try saveEnvironmentToKeychain(environment)
    } catch {
      // Log keychain errors but don't fail - saving is best-effort
      ClerkLogger.logError(
        error,
        message: "Failed to save environment to keychain. This is non-critical but may affect offline functionality."
      )
    }
  }

  /// Deletes cached client data from keychain.
  func deleteClient() {
    do {
      try keychain.deleteItem(forKey: "cachedClient")
    } catch {
      // Log keychain errors but don't fail - deletion is best-effort
      ClerkLogger.logError(
        error,
        message: "Failed to delete cached client from keychain. This is non-critical."
      )
    }
  }

  // MARK: - Private Keychain Operations

  /// Saves client data to keychain.
  private func saveClientToKeychain(_ client: Client) throws {
    let clientData = try JSONEncoder.clerkEncoder.encode(client)
    try keychain.set(clientData, forKey: "cachedClient")
  }

  /// Loads client data from keychain.
  private func loadClientFromKeychain() throws -> Client? {
    guard let clientData = try keychain.data(forKey: "cachedClient") else {
      return nil
    }
    let decoder = JSONDecoder.clerkDecoder
    return try decoder.decode(Client.self, from: clientData)
  }

  /// Saves environment data to keychain.
  private func saveEnvironmentToKeychain(_ environment: Clerk.Environment) throws {
    let encoder = JSONEncoder.clerkEncoder
    let environmentData = try encoder.encode(environment)
    try keychain.set(environmentData, forKey: "cachedEnvironment")
  }

  /// Loads environment data from keychain.
  private func loadEnvironmentFromKeychain() throws -> Clerk.Environment? {
    guard let environmentData = try keychain.data(forKey: "cachedEnvironment") else {
      return nil
    }
    let decoder = JSONDecoder.clerkDecoder
    return try decoder.decode(Clerk.Environment.self, from: environmentData)
  }
}
