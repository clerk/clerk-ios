#if os(iOS)

@testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct UpdateRequiredAppearanceTests {
  init() {
    AppearanceProbe.reset()
  }

  @Test
  func usesTheAppsTheme() {
    let store = UpdateRequiredAppearanceStore()
    var applied = ClerkTheme()
    applied.colors.primary = .mint
    store.appliedTheme = applied

    #expect(store.presentedAppearance.theme.colors.primary == .mint)
  }

  @Test
  func usesTheDefaultThemeBeforeAnyThemeIsSet() {
    let store = UpdateRequiredAppearanceStore()

    #expect(store.presentedAppearance.theme.colors.primary == ClerkTheme.default.colors.primary)
  }

  @Test
  func usesTheAppsIcon() {
    let store = UpdateRequiredAppearanceStore()
    store.appliedAppIcon = Image(systemName: "star")
    store.appliedAppIconMaxHeight = 72

    let presented = store.presentedAppearance
    #expect(presented.appIcon == Image(systemName: "star"))
    #expect(presented.appIconMaxHeight == 72)
  }

  @Test
  func leavesTheLogoToTheDashboardWithoutASetIcon() {
    let store = UpdateRequiredAppearanceStore()

    #expect(store.presentedAppearance.appIcon == nil)
    #expect(store.presentedAppearance.appIconMaxHeight == 44)
  }

  @Test
  func theRecorderKeepsTheFirstValuesAndPublishesThem() async throws {
    let store = UpdateRequiredAppearanceStore()
    let recorder = UpdateRequiredAppearanceRecorder { store }
    var first = ClerkTheme()
    first.colors.primary = .mint
    var second = ClerkTheme()
    second.colors.primary = .green

    recorder.record(.theme(first))
    recorder.record(.theme(second))
    recorder.record(.appIcon(Image(systemName: "star")))
    recorder.record(.appIcon(Image(systemName: "moon")))
    recorder.record(.appIconMaxHeight(72))
    recorder.record(.appIconMaxHeight(96))
    try await waitUntil { store.appliedTheme != nil }

    #expect(store.appliedTheme?.colors.primary == .mint)
    #expect(store.appliedAppIcon == Image(systemName: "star"))
    #expect(store.appliedAppIconMaxHeight == 72)
  }

  @Test
  func theThemeSetterRecordsTheAppsTheme() async throws {
    let store = UpdateRequiredAppearanceStore()
    var theme = ClerkTheme()
    theme.colors.primary = .mint
    let app = Color.clear
      .environment(\.clerkTheme, theme)
      .environment(\.updateRequiredAppearanceRecorder, UpdateRequiredAppearanceRecorder { store })

    try await render(app) { store.appliedTheme != nil }

    #expect(store.appliedTheme?.colors.primary == .mint)
  }

  @Test
  func keepsTheRootThemeWhenAPartOfTheAppOverridesIt() async throws {
    let store = UpdateRequiredAppearanceStore()
    var root = ClerkTheme()
    root.colors.primary = .mint
    let app = VStack {
      Color.clear
      Color.clear.environment(\.clerkTheme.colors.primary, .green)
    }
    .environment(\.clerkTheme, root)
    .environment(\.updateRequiredAppearanceRecorder, UpdateRequiredAppearanceRecorder { store })

    try await render(app) { store.appliedTheme != nil }
    try await Task.sleep(for: .milliseconds(50))

    #expect(store.appliedTheme?.colors.primary == .mint)
  }

  @Test
  func theAppIconModifiersRecordTheAppsIcon() async throws {
    let store = UpdateRequiredAppearanceStore()
    let app = Color.clear
      .clerkAppIcon(Image(systemName: "star"))
      .clerkAppIcon(maxHeight: 72)
      .environment(\.updateRequiredAppearanceRecorder, UpdateRequiredAppearanceRecorder { store })

    try await render(app) { store.appliedAppIcon != nil && store.appliedAppIconMaxHeight != nil }

    #expect(store.appliedAppIcon == Image(systemName: "star"))
    #expect(store.appliedAppIconMaxHeight == 72)
  }

  @Test
  func theUpdateWindowsOwnValuesAreNotRecorded() async throws {
    let store = UpdateRequiredAppearanceStore()
    let window = AppearanceProbeView()
      .updateRequiredAppearance(.init(theme: .default, appIcon: Image(systemName: "star"), appIconMaxHeight: 72))
      .environment(\.updateRequiredAppearanceRecorder, UpdateRequiredAppearanceRecorder { store })

    try await render(window) { AppearanceProbe.primaryColor != nil }
    try await Task.sleep(for: .milliseconds(50))

    #expect(store.appliedTheme == nil)
    #expect(store.appliedAppIcon == nil)
    #expect(store.appliedAppIconMaxHeight == nil)
  }

  @Test
  func appearanceReachesThePresentedView() async throws {
    var theme = ClerkTheme()
    theme.colors.primary = .orange
    let appearance = UpdateRequiredAppearance(theme: theme, appIcon: Image(systemName: "star"), appIconMaxHeight: 72)

    try await render(AppearanceProbeView().updateRequiredAppearance(appearance)) { AppearanceProbe.primaryColor != nil }

    #expect(AppearanceProbe.primaryColor == .orange)
    #expect(AppearanceProbe.appIcon == Image(systemName: "star"))
    #expect(AppearanceProbe.appIconMaxHeight == 72)
  }

  @Test
  func aLaterRecordedValueUpdatesThePresentedView() async throws {
    let store = UpdateRequiredAppearanceStore()
    let window = try await render(StoreBackedProbeView(store: store)) { AppearanceProbe.appIconMaxHeight == 44 }

    store.appliedAppIconMaxHeight = 96
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

  private func layout(_ window: UIWindow, until condition: () -> Bool) async throws {
    window.isHidden = false
    for _ in 0 ..< 100 where !condition() {
      window.layoutIfNeeded()
      try await Task.sleep(for: .milliseconds(10))
    }
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0 ..< 100 where !condition() {
      try await Task.sleep(for: .milliseconds(10))
    }
  }
}

@MainActor
private enum AppearanceProbe {
  static var primaryColor: Color?
  static var appIcon: Image?
  static var appIconMaxHeight: CGFloat?

  static func reset() {
    primaryColor = nil
    appIcon = nil
    appIconMaxHeight = nil
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
  let store: UpdateRequiredAppearanceStore

  var body: some View {
    AppearanceProbeView().updateRequiredAppearance(store.presentedAppearance)
  }
}

#endif
