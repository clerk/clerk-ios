//
//  ClerkButtonConfig.swift
//  Clerk
//
//  Created by Mike Pitre on 4/17/25.
//

#if canImport(SwiftUI)

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
