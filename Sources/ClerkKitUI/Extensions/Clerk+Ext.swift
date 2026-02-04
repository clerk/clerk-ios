//
//  Clerk+Ext.swift
//  Clerk
//

#if os(iOS)

import ClerkKit

extension Clerk {
  func resolvedUser(treatPendingAsSignedOut: Bool) -> User? {
    treatPendingAsSignedOut ? activeUser : user
  }
}

#endif
