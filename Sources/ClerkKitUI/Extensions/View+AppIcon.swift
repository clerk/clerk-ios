//
//  View+AppIcon.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

extension EnvironmentValues {
  @Entry var clerkAppIcon: Image?
  @Entry var clerkAppIconMaxHeight: CGFloat = 44
  @Entry var clerkAppIconView: AnyView?
}

extension View {
  /// Overrides the default app logo shown by ClerkKitUI authentication screens.
  ///
  /// Use this when you want to render a local app icon (or any custom image)
  /// instead of the dashboard-configured brand logo URL. ClerkKitUI makes the
  /// image resizable, scales it to fit, and applies its managed sizing and spacing.
  /// Use ``clerkAppIconView(content:)`` when you need full control over the logo view.
  ///
  /// - Parameter image: The custom image to render above auth content.
  /// - Returns: A view with a custom Clerk app icon configuration.
  public func clerkAppIcon(_ image: Image?) -> some View {
    environment(\.clerkAppIcon, image)
      .recordUpdateRequiredAppearance(.appIcon, value: image) {
        UpdateRequiredAppearance.shared.appIcon = $0
      }
  }

  /// Overrides the maximum height of the app logo shown by ClerkKitUI authentication screens.
  ///
  /// The logo maintains its aspect ratio and uses a maximum height of 44 points by default.
  /// This modifier applies to both the dashboard-configured brand logo and a custom logo set
  /// with ``clerkAppIcon(_:)``. It does not apply to a fully custom logo view set with
  /// ``clerkAppIconView(content:)``.
  ///
  /// - Parameter maxHeight: The maximum height of the app logo, in points.
  /// - Returns: A view with a custom Clerk app icon maximum height.
  public func clerkAppIcon(maxHeight: CGFloat) -> some View {
    environment(\.clerkAppIconMaxHeight, maxHeight)
      .recordUpdateRequiredAppearance(.appIconMaxHeight, value: maxHeight) {
        UpdateRequiredAppearance.shared.appIconMaxHeight = $0
      }
  }

  /// Replaces the entire app logo slot shown by ClerkKitUI authentication screens.
  ///
  /// Unlike ``clerkAppIcon(_:)``, ClerkKitUI does not apply resizing, content mode,
  /// frame, or spacing modifiers to this view. The custom view takes precedence over
  /// the dashboard-configured logo and other app icon modifiers. You are responsible
  /// for its layout and accessibility.
  ///
  /// The update-required screen that ClerkKitUI presents automatically captures
  /// this content, and the environment it's declared in, when the modified view appears.
  /// Environment objects the content reads stay available there and the color scheme
  /// follows the system; values passed in when building it don't update.
  ///
  /// - Parameter content: A view builder that creates the custom app logo content.
  /// - Returns: A view with fully custom Clerk app icon content.
  public func clerkAppIconView(
    @ViewBuilder content: () -> some View
  ) -> some View {
    let appIconView = AnyView(content())
    return environment(\.clerkAppIconView, appIconView)
      .recordUpdateRequiredAppearanceOnAppear(.appIconView) { environment in
        UpdateRequiredAppearance.shared.appIconView = appIconView
        UpdateRequiredAppearance.shared.appIconEnvironment = environment
      }
  }
}

#endif
