//
//  ClerkTheme.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation
import SwiftUI

/// A top-level theme container that customizes the appearance of ClerkKitUI views.
///
/// `ClerkTheme` groups semantic `colors`, Dynamic Type-aligned `fonts`, and shared
/// `design` tokens. Apply it with ``SwiftUICore/View/clerkTheme(_:)`` on your root
/// view. To change a few tokens, set them on a `ClerkTheme()` and pass it to
/// `clerkTheme(_:)`.
///
/// The update-required screen that ClerkKitUI presents automatically uses only the
/// theme set with `clerkTheme(_:)`. A theme set with `.environment(\.clerkTheme, ...)`
/// still styles views inside your hierarchy, but not that screen.
public struct ClerkTheme: Sendable, Equatable {
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
