//
//  BiometricCredentialPolicy.swift
//  Clerk
//

import Foundation

/// The local authentication policy used to protect a biometric-credential private key.
public enum BiometricCredentialPolicy: String, Codable, Equatable, Sendable {
  /// Require a biometric from the currently enrolled set.
  ///
  /// Adding or removing Face ID / Touch ID enrollment invalidates the private key.
  case biometryCurrentSet = "biometry_current_set"

  /// Require biometric authentication, but allow biometric enrollment changes.
  /// Supported for sign-in; reverification requires ``biometryCurrentSet``.
  case biometryAny = "biometry_any"

  /// Require biometric availability at enrollment, then allow biometric or device passcode authentication.
  ///
  /// This permits the device passcode to unlock the biometric credential during sign-in.
  /// Reverification requires ``biometryCurrentSet``.
  case biometryOrDevicePasscode = "biometry_or_device_passcode"
}
