//
//  BiometricCredentialAvailability+Enrollment.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit

extension BiometricCredentialAvailability {
  var canPromptForEnrollment: Bool {
    switch unavailableReason {
    case .noLocalCredential,
         .localKeyMissing,
         .serverCredentialMissing,
         .serverCredentialRevoked:
      true
    default:
      false
    }
  }
}

#endif
