#if os(iOS)

@testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct UpdateRequiredAppearanceTests {
  private let logoURL = "https://img.clerk.com/logo.png"

  init() {
    UpdateRequiredView.appearance = .init()
    AppearanceProbe.reset()
  }

  @Test
  func defaultAppearanceUsesTheDashboardLogo() {
    let appearance = UpdateRequiredView.Appearance()

    #expect(appearance.theme == nil)
    #expect(appearance.appIcon == nil)
    #expect(appearance.appIconView == nil)
    #expect(appearance.appIconMaxHeight == 44)
  }

  /// These use their own store: other suites show ClerkKitUI views, which record their theme in
  /// the shared one at the same time.
  @Test
  func usesTheThemeOfAShownClerkViewWhenNoneIsSet() async throws {
    let store = UpdateRequiredAppearanceStore()
    var theme = ClerkTheme()
    theme.colors.primary = .orange
    let shown = Color.clear
      .modifier(RecordThemeForUpdateRequiredViewModifier(store: store))
      .environment(\.clerkTheme, theme)

    try await render(shown) { store.shownTheme != nil }

    #expect(store.presentedAppearance(dashboardLogoURL: logoURL).theme?.colors.primary == .orange)
  }

  @Test
  func aThemeSetInTheAppearanceWinsOverAShownOne() {
    let store = UpdateRequiredAppearanceStore()
    var shown = ClerkTheme()
    shown.colors.primary = .orange
    var set = ClerkTheme()
    set.colors.primary = .purple
    store.shownTheme = shown
    store.appearance.theme = set

    #expect(store.presentedAppearance(dashboardLogoURL: logoURL).theme?.colors.primary == .purple)
  }

  @Test
  func usesTheDefaultThemeBeforeAnyClerkViewIsShown() {
    let store = UpdateRequiredAppearanceStore()

    #expect(store.presentedAppearance(dashboardLogoURL: logoURL).theme?.colors.primary == ClerkTheme.default.colors.primary)
  }

  @Test
  func fallsBackToTheAppIconOnlyWithoutADashboardLogoOrASetIcon() {
    let store = UpdateRequiredAppearanceStore()
    let bundleIcon = { Image(systemName: "app") }

    #expect(store.presentedAppearance(dashboardLogoURL: "", bundleIcon: bundleIcon).appIcon == Image(systemName: "app"))
    #expect(store.presentedAppearance(dashboardLogoURL: nil, bundleIcon: bundleIcon).appIcon == Image(systemName: "app"))
    #expect(store.presentedAppearance(dashboardLogoURL: logoURL, bundleIcon: bundleIcon).appIcon == nil)

    store.appearance.appIcon = Image(systemName: "star")
    #expect(store.presentedAppearance(dashboardLogoURL: "", bundleIcon: bundleIcon).appIcon == Image(systemName: "star"))
  }

  @Test
  func appearanceReachesThePresentedView() async throws {
    var theme = ClerkTheme()
    theme.colors.primary = .orange
    let appearance = UpdateRequiredView.Appearance(theme: theme, appIcon: Image(systemName: "star"), appIconMaxHeight: 72)

    try await render(AppearanceProbeView().updateRequiredAppearance(appearance)) { AppearanceProbe.primaryColor != nil }

    #expect(AppearanceProbe.primaryColor == .orange)
    #expect(AppearanceProbe.appIcon == Image(systemName: "star"))
    #expect(AppearanceProbe.appIconMaxHeight == 72)
  }

  @Test
  func appIconViewGetsTheEnvironmentObjectsGivenToIt() async throws {
    let appearance = UpdateRequiredView.Appearance {
      EnvironmentObjectIcon().environmentObject(IconModel(name: "star"))
    }

    let icon = try #require(appearance.appIconView)
    try await render(icon) { AppearanceProbe.renderedIconName != nil }

    #expect(AppearanceProbe.renderedIconName == "star")
  }

  @Test
  func changingTheAppearanceUpdatesThePresentedView() async throws {
    let window = try await render(StoreBackedProbeView()) { AppearanceProbe.appIconMaxHeight == 44 }

    UpdateRequiredView.appearance.appIconMaxHeight = 96
    try await layout(window) { AppearanceProbe.appIconMaxHeight == 96 }

    #expect(AppearanceProbe.appIconMaxHeight == 96)
  }

  @discardableResult
  private func render(_ view: some View, until condition: () -> Bool) async throws -> UIWindow {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = UIHostingController(rootView: view)
    window.isHidden = false
    try await layout(window, until: condition)
    return window
  }

  /// Lays the window out until `condition` holds, or for one second when it never does.
  private func layout(_ window: UIWindow, until condition: () -> Bool) async throws {
    window.isHidden = false
    for _ in 0 ..< 100 where !condition() {
      window.layoutIfNeeded()
      try await Task.sleep(for: .milliseconds(10))
    }
  }
}

@MainActor
private enum AppearanceProbe {
  static var primaryColor: Color?
  static var appIcon: Image?
  static var appIconMaxHeight: CGFloat?
  static var renderedIconName: String?

  static func reset() {
    primaryColor = nil
    appIcon = nil
    appIconMaxHeight = nil
    renderedIconName = nil
  }
}

private struct AppearanceProbeView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.clerkAppIcon) private var appIcon
  @Environment(\.clerkAppIconMaxHeight) private var appIconMaxHeight

  var body: some View {
    Color.clear
      .onAppear {
        AppearanceProbe.primaryColor = theme.colors.primary
        AppearanceProbe.appIcon = appIcon
      }
      .onChange(of: appIconMaxHeight, initial: true) { _, height in
        AppearanceProbe.appIconMaxHeight = height
      }
  }
}

private struct StoreBackedProbeView: View {
  private let store = UpdateRequiredAppearanceStore.shared

  var body: some View {
    AppearanceProbeView().updateRequiredAppearance(store.appearance)
  }
}

private final class IconModel: ObservableObject {
  let name: String

  init(name: String) {
    self.name = name
  }
}

private struct EnvironmentObjectIcon: View {
  @EnvironmentObject private var model: IconModel

  var body: some View {
    Image(systemName: model.name)
      .onAppear { AppearanceProbe.renderedIconName = model.name }
  }
}

#endif
