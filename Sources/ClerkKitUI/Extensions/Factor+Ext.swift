//
//  Factor+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 4/23/25.
//

#if os(iOS)

import Foundation

extension Factor {
  var isResetFactor: Bool {
    [
      "reset_password_email_code",
      "reset_password_phone_code",
    ].contains(strategy)
  }
}

#endif
