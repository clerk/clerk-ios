import Foundation

/// Errors produced by local biometric credential operations.
public enum BiometricCredentialError: String, Error, LocalizedError, CustomNSError, Sendable {
  /// Reverification requires a credential enrolled with `biometryCurrentSet`.
  case policyIncompatible = "biometric_credential_policy_incompatible"

  public var errorDescription: String? {
    switch self {
    case .policyIncompatible:
      "This biometric credential cannot be used for reverification. Verify your identity using another method."
    }
  }

  public static var errorDomain: String {
    "ClerkKit.BiometricCredentialError"
  }

  public var errorCode: Int {
    switch self {
    case .policyIncompatible: 1
    }
  }

  public var errorUserInfo: [String: Any] {
    ["code": rawValue, NSLocalizedDescriptionKey: errorDescription ?? rawValue]
  }
}
