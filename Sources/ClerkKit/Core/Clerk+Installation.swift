//
//  Clerk+Installation.swift
//  Clerk
//

import Foundation

extension Clerk {
  @MainActor
  package static var installationMarkerUserDefaults: UserDefaults = .standard
  @MainActor
  package static var biometricCredentialAppIdentifierProvider: () -> String? = {
    Bundle.main.bundleIdentifier
  }

  private static let biometricCredentialInstallationMarkerPrefix = "com.clerk.trusted-device-installation-marker"

  @MainActor
  package func reconcileBiometricCredentialsForCurrentInstallation() {
    guard let appIdentifier = Self.biometricCredentialAppIdentifierProvider() else {
      return
    }

    let markerKey = Self.biometricCredentialInstallationMarkerKey(
      for: options.keychainConfig,
      appIdentifier: appIdentifier
    )
    guard Self.installationMarkerUserDefaults.object(forKey: markerKey) as? Bool != true else {
      return
    }

    do {
      try dependencies.biometricCredentialStore
        .deleteLocalCredentials(
          appIdentifier: appIdentifier,
          keyManager: dependencies.biometricCredentialKeyManager
        )
      Self.installationMarkerUserDefaults.set(true, forKey: markerKey)
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to clear biometric local credentials for a new app installation."
      )
    }
  }

  package static func biometricCredentialInstallationMarkerKey(
    for keychainConfig: Options.KeychainConfig,
    appIdentifier: String
  ) -> String {
    [
      biometricCredentialInstallationMarkerPrefix,
      encodeInstallationMarkerComponent(keychainConfig.service),
      encodeInstallationMarkerComponent(keychainConfig.accessGroup),
      encodeInstallationMarkerComponent(appIdentifier),
    ].joined(separator: ".")
  }

  private static func encodeInstallationMarkerComponent(_ value: String?) -> String {
    guard let value else { return "n" }
    return "s\(value.utf8.count):\(value)"
  }
}
