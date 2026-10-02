//
//  CacheManager.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

protocol CacheCoordinator: AnyObject, Sendable {
  /// Sets the environment if the current environment is empty.
  @MainActor func setEnvironmentIfNeeded(_ environment: Clerk.Environment)
}

@MainActor
final class CacheManager {
  private weak var coordinator: (any CacheCoordinator)?
  private let keychain: any KeychainStorage
  private var isShutdown = false

  init(coordinator: any CacheCoordinator, keychain: any KeychainStorage) {
    self.coordinator = coordinator
    self.keychain = keychain
  }

  func loadCachedData() {
    do {
      guard let data = try keychain.data(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) else {
        return
      }
      let environment = try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: data)
      coordinator?.setEnvironmentIfNeeded(environment)
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to load cached environment from keychain. This is non-critical and initialization will continue."
      )
    }
  }

  func saveEnvironment(_ environment: Clerk.Environment) {
    guard !isShutdown else { return }
    do {
      try keychain.set(
        JSONEncoder.clerkEncoder.encode(environment),
        forKey: ClerkKeychainKey.cachedEnvironment.rawValue
      )
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to save environment to keychain. This is non-critical but may affect offline functionality."
      )
    }
  }

  func shutdown() {
    isShutdown = true
    coordinator = nil
  }
}

extension CacheManager: ClerkInternalStateChangeObserver {
  func handle(_ change: ClerkInternalStateChange, from clerk: Clerk) throws {
    guard case .environmentDidChange = change, let environment = clerk.environment else { return }
    saveEnvironment(environment)
  }
}
