//
//  SocialButtonLayoutConfiguration.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

enum SocialButtonLayoutConfiguration {
  #if os(iOS)
  static func stacksTwoItemsInSingleColumn(horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
    horizontalSizeClass == .compact
  }
  #else
  static func stacksTwoItemsInSingleColumn() -> Bool {
    false
  }
  #endif
}

#endif
