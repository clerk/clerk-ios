//
//  TrustedDeviceAvailability+Enrollment.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit

extension TrustedDeviceAvailability {
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
