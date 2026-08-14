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
    guard let clerkError = self as? ClerkAPIError else {
      return .stop
    }

    switch clerkError.code {
    case "form_code_incorrect", "totp_incorrect_code":
      return .submitPendingCode
    default:
      return .stop
    }
  }
}

#endif
