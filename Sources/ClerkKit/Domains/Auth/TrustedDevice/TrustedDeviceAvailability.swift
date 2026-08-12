//
//  TrustedDeviceAvailability.swift
//  Clerk
//

import Foundation

/// Local availability state for biometric trusted-device sign-in.
public enum TrustedDeviceAvailability: Equatable, Sendable {
  case available
  case unavailable(UnavailableReason)

  /// Whether the SDK has a local credential and key that can be used for trusted-device sign-in.
  public var isAvailable: Bool {
    switch self {
    case .available:
      true
    case .unavailable:
      false
    }
  }

  /// The reason trusted-device sign-in is unavailable, if any.
  public var unavailableReason: UnavailableReason? {
    switch self {
    case .available:
      nil
    case let .unavailable(reason):
      reason
    }
  }

  public enum UnavailableReason: String, Codable, Equatable, Sendable {
    case environmentUnavailable
    case nativeAPIDisabled
    case featureDisabled
    case unsupportedPlatform
    case biometricAuthenticationUnavailable
    case noLocalCredential
    case localKeyMissing
    case serverCredentialMissing
    case serverCredentialRevoked
  }
}
