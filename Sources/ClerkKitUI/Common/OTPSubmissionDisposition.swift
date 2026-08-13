//
//  OTPSubmissionDisposition.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit

enum OTPSubmissionDisposition: Equatable {
  case stop
  case submitPendingCode
}

extension Error {
  var otpSubmissionDisposition: OTPSubmissionDisposition {
    guard let clerkError = self as? ClerkAPIError,
          clerkError.code == "form_code_incorrect"
    else {
      return .stop
    }

    return .submitPendingCode
  }
}

#endif
