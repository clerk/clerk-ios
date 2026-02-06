//
//  ClerkButtonConfig.swift
//  Clerk
//

#if os(iOS)

import Foundation

struct ClerkButtonConfig {
  var emphasis: Emphasis = .high
  var size: Size = .large

  enum Emphasis {
    case none
    case low
    case high
  }

  enum Size {
    case small
    case large
  }
}

#endif
