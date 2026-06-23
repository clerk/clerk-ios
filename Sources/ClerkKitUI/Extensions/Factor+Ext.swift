//
//  Factor+Ext.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation

extension Factor {
  var isResetFactor: Bool {
    strategy == .resetPasswordEmailCode || strategy == .resetPasswordPhoneCode
  }

  var authStartField: AuthStartField? {
    switch strategy {
    case .phoneCode, .resetPasswordPhoneCode:
      .phoneNumber
    case .emailCode, .emailLink, .resetPasswordEmailCode:
      .emailOrUsername
    case .password, .passkey:
      phoneNumberId != nil || safeIdentifier?.looksLikePhoneNumber == true ? .phoneNumber : .emailOrUsername
    default:
      nil
    }
  }
}

#endif
