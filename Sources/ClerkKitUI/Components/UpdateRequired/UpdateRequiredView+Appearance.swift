//
//  UpdateRequiredView+Appearance.swift
//  Clerk
//

#if os(iOS)

import SwiftUI

extension UpdateRequiredView {
  /// The theme and app icon of the ``UpdateRequiredView`` that Clerk presents over your app on its own.
  ///
  /// Clerk presents that view in its own window, outside your view hierarchy. By default it uses the
  /// theme of the ClerkKitUI views your app has shown, such as ``AuthView`` or ``UserButton``, and
  /// the logo set in the Clerk Dashboard, or your app's icon when there's none. To choose them
  /// yourself, set them here, typically where you configure Clerk. Set only what you want to change:
  ///
  /// ```swift
  /// UpdateRequiredView.appearance.appIcon = Image("Logo")
  /// ```
  ///
  /// Assigning a new ``Appearance`` replaces every setting, so anything you leave out goes back to
  /// its default.
  ///
  /// When you place ``UpdateRequiredView`` yourself, it uses your view hierarchy's theme and app
  /// icon like any other ClerkKitUI view, and this setting doesn't apply.
  @MainActor
  public static var appearance: Appearance {
    get { UpdateRequiredAppearanceStore.shared.appearance }
    set { UpdateRequiredAppearanceStore.shared.appearance = newValue }
  }

  /// The theme and app icon of the ``UpdateRequiredView`` that Clerk presents automatically.
  public struct Appearance {
    /// The theme of the view. When `nil`, the view uses the theme of the ClerkKitUI views your app
    /// has shown, or the default theme before any has appeared.
    public var theme: ClerkTheme?

    /// An image to show instead of the logo set in the Clerk Dashboard, or your app's icon when
    /// there's none. ClerkKitUI sizes it to fit ``appIconMaxHeight``.
    public var appIcon: Image?

    /// The maximum height of the app logo, in points.
    public var appIconMaxHeight: CGFloat

    /// A view to show in place of the app logo, laid out as is. It takes precedence over
    /// ``appIcon``. It's drawn in Clerk's window, so give it any environment objects it reads.
    public var appIconView: AnyView?

    /// Creates an appearance.
    ///
    /// - Parameters:
    ///   - theme: The theme of the view, or `nil` to use the theme of the ClerkKitUI views your app
    ///     has shown.
    ///   - appIcon: An image to show instead of the logo set in the Clerk Dashboard.
    ///   - appIconMaxHeight: The maximum height of the app logo, in points.
    public init(theme: ClerkTheme? = nil, appIcon: Image? = nil, appIconMaxHeight: CGFloat = 44) {
      self.theme = theme
      self.appIcon = appIcon
      self.appIconMaxHeight = appIconMaxHeight
      appIconView = nil
    }

    /// Creates an appearance with a custom view in place of the app logo.
    ///
    /// - Parameters:
    ///   - theme: The theme of the view, or `nil` to use the theme of the ClerkKitUI views your app
    ///     has shown.
    ///   - appIconView: A view to show in place of the app logo, laid out as is.
    public init(theme: ClerkTheme? = nil, @ViewBuilder appIconView: () -> some View) {
      self.init(theme: theme)
      self.appIconView = AnyView(appIconView())
    }
  }
}

@MainActor
@Observable
final class UpdateRequiredAppearanceStore {
  static let shared = UpdateRequiredAppearanceStore()

  var appearance = UpdateRequiredView.Appearance()
  var shownTheme: ClerkTheme?

  func presentedAppearance(dashboardLogoURL: String?, bundleIcon: () -> Image? = { Image.appIcon }) -> UpdateRequiredView.Appearance {
    var presented = appearance
    presented.theme = appearance.theme ?? shownTheme ?? .default
    if presented.appIcon == nil, presented.appIconView == nil, dashboardLogoURL?.isEmpty ?? true {
      presented.appIcon = bundleIcon()
    }
    return presented
  }
}

extension View {
  func updateRequiredAppearance(_ appearance: UpdateRequiredView.Appearance) -> some View {
    environment(\.clerkTheme, appearance.theme ?? .default)
      .environment(\.clerkAppIcon, appearance.appIcon)
      .environment(\.clerkAppIconMaxHeight, appearance.appIconMaxHeight)
      .environment(\.clerkAppIconView, appearance.appIconView)
  }
}

struct RecordThemeForUpdateRequiredViewModifier: ViewModifier {
  @Environment(\.clerkTheme) private var theme

  var store = UpdateRequiredAppearanceStore.shared

  func body(content: Content) -> some View {
    content.onAppear {
      store.shownTheme = theme
    }
  }
}

extension Image {
  @MainActor static let appIcon: Image? = makeAppIcon()

  private static func makeAppIcon() -> Image? {
    guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
          let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
          let name = (primaryIcon["CFBundleIconFiles"] as? [String])?.last,
          let icon = UIImage(named: name)
    else {
      return nil
    }
    let rounded = UIGraphicsImageRenderer(size: icon.size).image { _ in
      UIBezierPath(roundedRect: CGRect(origin: .zero, size: icon.size), cornerRadius: icon.size.width * 0.2237).addClip()
      icon.draw(at: .zero)
    }
    return Image(uiImage: rounded)
  }
}

#endif

#if os(iOS) || os(macOS)

import SwiftUI

extension View {
  func recordsThemeForUpdateRequiredView() -> some View {
    #if os(iOS)
    modifier(RecordThemeForUpdateRequiredViewModifier())
    #else
    self
    #endif
  }
}

#endif
