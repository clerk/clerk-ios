//
//  Clerk+Installation.swift
//  Clerk
//

import Foundation

extension Clerk {
  @MainActor
  package static var installationMarkerUserDefaults: UserDefaults = .standard
  @MainActor
  package static var trustedDeviceAppIdentifierProvider: () -> String? = {
    Bundle.main.bundleIdentifier
  }

  private static let trustedDeviceInstallationMarkerPrefix = "com.clerk.trusted-device-installation-marker"

  @MainActor
  package func reconcileTrustedDeviceCredentialsForCurrentInstallation() {
    guard let appIdentifier = Self.trustedDeviceAppIdentifierProvider() else {
      return
    }

    let markerKey = Self.trustedDeviceInstallationMarkerKey(
      for: options.keychainConfig,
      appIdentifier: appIdentifier
    )
    guard Self.installationMarkerUserDefaults.object(forKey: markerKey) as? Bool != true else {
      return
    }

    let legacyMarkerKey = Self.trustedDeviceInstallationMarkerKey(for: options.keychainConfig)
    if Self.installationMarkerUserDefaults.object(forKey: legacyMarkerKey) as? Bool == true {
      Self.installationMarkerUserDefaults.set(true, forKey: markerKey)
      return
    }

    do {
      try dependencies.trustedDeviceCredentialStore
        .deleteLocalCredentials(
          appIdentifier: appIdentifier,
          keyManager: dependencies.trustedDeviceKeyManager
        )
      Self.installationMarkerUserDefaults.set(true, forKey: markerKey)
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to clear trusted-device local credentials for a new app installation."
      )
    }
  }

  private static func trustedDeviceInstallationMarkerKey(for keychainConfig: Options.KeychainConfig) -> String {
    [
      trustedDeviceInstallationMarkerPrefix,
      keychainConfig.service,
      keychainConfig.accessGroup ?? "default",
    ].joined(separator: ".")
  }

  private static func trustedDeviceInstallationMarkerKey(
    for keychainConfig: Options.KeychainConfig,
    appIdentifier: String
  ) -> String {
    [
      trustedDeviceInstallationMarkerKey(for: keychainConfig),
      appIdentifier,
    ].joined(separator: ".")
  }
}
