//
//  TrustedDevicePolicy.swift
//  Clerk
//

import Foundation

/// The local authentication policy used to protect a trusted-device private key.
public enum TrustedDevicePolicy: String, Codable, Equatable, Sendable {
  /// Require a biometric from the currently enrolled set.
  ///
  /// Adding or removing Face ID / Touch ID enrollment invalidates the private key.
  case biometryCurrentSet = "biometry_current_set"

  /// Require biometric authentication, but allow biometric enrollment changes.
  case biometryAny = "biometry_any"

  /// Require biometric availability at enrollment, then allow biometric or device passcode authentication.
  ///
  /// This permits the device passcode to unlock the trusted-device credential during sign-in.
  case biometryOrDevicePasscode = "biometry_or_device_passcode"
}
