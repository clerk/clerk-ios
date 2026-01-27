//
//  ClerkTheme.swift
//  Clerk
//
//  Created by Mike Pitre on 4/9/25.
//

#if os(iOS)

import Foundation
import SwiftUI

/// A top-level theme container that customizes the appearance of Clerk iOS views.
///
/// `ClerkTheme` groups semantic `colors`, Dynamic Type-aligned `fonts`, and shared
/// `design` tokens. Apply it with `.environment(\.clerkTheme, ...)` on your root
/// view, or override individual properties such as
/// `.environment(\.clerkTheme.colors.primary, ...)` for more targeted changes.
@MainActor
@Observable
public class ClerkTheme {
  /// Color tokens used throughout ClerkKitUI components.
  public var colors: Colors

  /// Typography tokens mapped to Dynamic Type text styles.
  public var fonts: Fonts

  /// Shared design tokens such as corner radius.
  public var design: Design

  /// Creates a new theme.
  ///
  /// - Parameters:
  ///   - colors: The color palette to apply.
  ///   - fonts: The typography scale to apply.
  ///   - design: Shared design tokens to apply.
  public init(
    colors: Colors = .default,
    fonts: Fonts = .default,
    design: Design = .default
  ) {
    self.colors = colors
    self.fonts = fonts
    self.design = design
  }
}

#endif
