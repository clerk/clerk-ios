//
//  Clerk+Installation.swift
//  Clerk
//

import Foundation

extension Clerk {
  @MainActor
  package static var installationMarkerUserDefaults: UserDefaults = .standard

  private static let trustedDeviceInstallationMarkerPrefix = "com.clerk.trusted-device-installation-marker"

  @MainActor
  package func reconcileTrustedDeviceCredentialsForCurrentInstallation() {
    let markerKey = Self.trustedDeviceInstallationMarkerKey(for: options.keychainConfig)
    guard Self.installationMarkerUserDefaults.object(forKey: markerKey) as? Bool != true else {
      return
    }

    do {
      try dependencies.trustedDeviceCredentialStore
        .deleteAllLocalCredentials(keyManager: dependencies.trustedDeviceKeyManager)
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
}
