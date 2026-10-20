//
//  View+ClerkTheme.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

extension View {
  /// Applies a theme to the ClerkKitUI views inside this view.
  ///
  /// Apply it to your root view so every ClerkKitUI view uses your theme, including the
  /// ``UpdateRequiredView`` that Clerk presents over your app on its own. That view lives in
  /// its own window, outside your view hierarchy, so it only gets a theme set with this
  /// modifier; a theme set with `.environment(\.clerkTheme, ...)` doesn't reach it.
  ///
  /// ```swift
  /// ContentView()
  ///   .clerkTheme(myTheme)
  /// ```
  ///
  /// When you set a theme on a screen inside one that already has one, that screen uses it,
  /// and ``UpdateRequiredView`` keeps using the outer theme.
  ///
  /// - Parameter theme: The theme to apply.
  /// - Returns: A view whose ClerkKitUI views use `theme`.
  public func clerkTheme(_ theme: ClerkTheme) -> some View {
    environment(\.clerkTheme, theme)
      .recordUpdateRequiredAppearance(.theme, value: theme) {
        UpdateRequiredAppearance.shared.theme = $0
      }
  }
}

#endif
