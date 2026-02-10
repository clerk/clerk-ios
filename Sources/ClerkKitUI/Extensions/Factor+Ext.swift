//
//  Factor+Ext.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import Foundation

extension Factor {
  var isResetFactor: Bool {
    strategy == .resetPasswordEmailCode || strategy == .resetPasswordPhoneCode
  }
}

#endif
