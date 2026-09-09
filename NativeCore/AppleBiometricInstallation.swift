import Foundation

/// The app container records installation continuity; private keys may outlive it.
@MainActor struct AppleBiometricInstallation {
  let defaults: UserDefaults
  let publishableKey: String
  let appIdentifier: String
  let legacy: LegacyKeychainConfiguration

  private func component(_ value: String?) -> String {
    guard let value else { return "n" }
    return "s\(value.utf8.count):\(value)"
  }

  private var currentKey: String {
    ["com.clerk.core.biometric-installation.v1", component(appIdentifier), component(publishableKey)].joined(separator: ".")
  }

  func isCurrent() -> Bool {
    if defaults.object(forKey: currentKey) as? Bool == true { return true }
    guard legacy.publishableKey == publishableKey else { return false }
    // Clerk+Installation.swift in baseline 02f98f89. Preserve UTF-8 lengths,
    // missing access groups, and the caller's legacy Keychain configuration.
    let legacyKey = ["com.clerk.trusted-device-installation-marker", component(legacy.service ?? appIdentifier), component(legacy.installationAccessGroup), component(appIdentifier)].joined(separator: ".")
    return defaults.object(forKey: legacyKey) as? Bool == true
  }

  func markCurrent() {
    defaults.set(true, forKey: currentKey)
  }
}
