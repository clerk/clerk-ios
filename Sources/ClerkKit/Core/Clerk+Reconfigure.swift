//
//  Clerk+Reconfigure.swift
//  ClerkKit
//

import Foundation

extension Clerk {
  /// Reconfigures the shared Clerk instance with a new publishable key and options.
  ///
  /// This method validates the new configuration, clears local Clerk state, and then
  /// installs the new configuration on the existing shared instance. Any user currently
  /// signed in should be expected to sign in again after reconfiguration.
  ///
  /// If Clerk has not been configured yet, this method creates and installs the shared
  /// instance without going through the fallback ``Clerk/shared`` getter.
  ///
  /// - Parameters:
  ///   - publishableKey: The new publishable key from your Clerk Dashboard.
  ///   - options: Configuration options for the Clerk instance.
  /// - Returns: The configured shared Clerk instance.
  /// - Throws: An error if the new configuration is invalid.
  ///
  /// Example:
  /// ```swift
  /// try await Clerk.reconfigure(
  ///   publishableKey: selectedRegion.publishableKey,
  ///   options: .init(proxyUrl: selectedRegion.proxyUrl)
  /// )
  /// ```
  @MainActor
  @discardableResult
  public static func reconfigure(
    publishableKey: String,
    options: Clerk.Options = .init()
  ) async throws -> Clerk {
    try beginRuntimeReconfiguration()
    defer { endRuntimeReconfiguration() }

    if let existing = _shared {
      let nextEpoch = existing.nextConfigurationEpoch
      let runtimeScope = ClerkRuntimeScope(epoch: nextEpoch) { [weak existing] in
        existing ?? Clerk.shared
      }
      let newDependencies = try DependencyContainer(
        publishableKey: publishableKey,
        options: options,
        runtimeScope: runtimeScope
      )
      let oldKeychain = existing.dependencies.keychain
      let newKeychain = newDependencies.keychain

      try clearAllKeychainItemsStrictly(in: newKeychain)

      existing.advanceConfigurationEpoch(to: nextEpoch)
      await existing.cleanupManagersForRuntimeReconfiguration()

      try clearAllKeychainItemsStrictly(in: oldKeychain)

      await existing.resetRuntimeStateForReconfiguration()
      existing.performConfiguration(dependencies: newDependencies)
      return existing
    }

    let clerk = Clerk()
    let newDependencies = try DependencyContainer(
      publishableKey: publishableKey,
      options: options,
      runtimeScope: clerk.runtimeScope
    )

    try clearAllKeychainItemsStrictly(in: newDependencies.keychain)

    clerk.performConfiguration(dependencies: newDependencies)
    _shared = clerk
    return clerk
  }

  @MainActor
  private func resetRuntimeStateForReconfiguration() async {
    client = nil
    environment = nil
    sessionsByUserId = [:]
    await WebAuthentication.cancelCurrentSession()

    #if canImport(AuthenticationServices) && !os(watchOS)
    PasskeyHelper.cancelCurrentAuthorization()
    #endif

    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()
  }
}
