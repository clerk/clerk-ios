//
//  View+AppIcon.swift
//  Clerk
//

#if os(iOS)

import SwiftUI

private struct ClerkAppIconEnvironmentKey: EnvironmentKey {
  static let defaultValue: Image? = nil
}

extension EnvironmentValues {
  var clerkAppIcon: Image? {
    get { self[ClerkAppIconEnvironmentKey.self] }
    set { self[ClerkAppIconEnvironmentKey.self] = newValue }
  }
}

extension View {
  /// Overrides the default app logo shown by ClerkKitUI authentication screens.
  ///
  /// Use this when you want to render a local app icon (or any custom image)
  /// instead of the dashboard-configured brand logo URL.
  ///
  /// - Parameter image: The custom image to render above auth content.
  /// - Returns: A view with a custom Clerk app icon configuration.
  public func clerkAppIcon(_ image: Image?) -> some View {
    environment(\.clerkAppIcon, image)
  }
}

#endif
