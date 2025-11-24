//
//  Factor+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 4/23/25.
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
