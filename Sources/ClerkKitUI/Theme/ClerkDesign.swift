//
//  ClerkDesign.swift
//  Clerk
//
//  Created by Mike Pitre on 4/10/25.
//

#if os(iOS)

import Foundation

extension ClerkTheme {
  /// Design tokens that control layout and shape across ClerkKitUI views.
  public struct Design {
    /// The default corner radius applied to ClerkKitUI surfaces.
    public var borderRadius: CGFloat

    /// Creates design tokens used by ClerkKitUI views.
    public init(
      borderRadius: CGFloat = Self.default.borderRadius
    ) {
      self.borderRadius = borderRadius
    }
  }
}

extension ClerkTheme.Design {
  /// The default set of design tokens used by ClerkKitUI.
  public nonisolated static var `default`: Self {
    .init(
      borderRadius: 6.0
    )
  }
}

#endif
