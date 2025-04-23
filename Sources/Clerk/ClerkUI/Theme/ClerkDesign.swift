//
//  ClerkDesign.swift
//  Clerk
//
//  Created by Mike Pitre on 4/10/25.
//

#if canImport(SwiftUI)

import Foundation

extension ClerkTheme {
  public struct Design {
    
    public var borderRadius: CGFloat
    
    public init(
      borderRadius: CGFloat = Self.default.borderRadius
    ) {
      self.borderRadius = borderRadius
    }
  }
}

extension ClerkTheme.Design {
  
  public static var `default`: Self {
    .init(
      borderRadius: 6.0
    )
  }
  
}

#endif
