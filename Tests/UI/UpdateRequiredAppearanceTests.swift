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
  func presentsTheRecordedValues() async throws {
    let store = UpdateRequiredAppearanceStore()
    var theme = ClerkTheme()
    theme.colors.primary = .orange
    store.theme = theme
    store.appIcon = Image(systemName: "star")
    store.appIconMaxHeight = 72

    try await render(StoreBackedProbeView(store: store)) { AppearanceProbe.primaryColor != nil }

    #expect(AppearanceProbe.primaryColor == .orange)
    #expect(AppearanceProbe.appIcon == Image(systemName: "star"))
    #expect(AppearanceProbe.appIconMaxHeight == 72)
  }

  @Test
  func presentsTheDefaultsBeforeAnythingIsRecorded() async throws {
    try await render(StoreBackedProbeView(store: UpdateRequiredAppearanceStore())) { AppearanceProbe.primaryColor != nil }

    #expect(AppearanceProbe.primaryColor == ClerkTheme.default.colors.primary)
    #expect(AppearanceProbe.appIcon == nil)
    #expect(AppearanceProbe.appIconMaxHeight == 44)
  }

  @Test
  func theRecorderKeepsTheFirstValuesAndPublishesThem() async {
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
    await mainQueueTurn()

    #expect(store.theme?.colors.primary == .mint)
    #expect(store.appIcon == Image(systemName: "star"))
    #expect(store.appIconMaxHeight == 72)
  }

  @Test
  func theThemeSetterRecordsTheAppsTheme() async throws {
    let store = UpdateRequiredAppearanceStore()
    var theme = ClerkTheme()
    theme.colors.primary = .mint
    let app = Color.clear
      .environment(\.clerkTheme, theme)
      .environment(\.updateRequiredAppearanceRecorder, UpdateRequiredAppearanceRecorder { store })

    try await render(app) { store.theme != nil }

    #expect(store.theme?.colors.primary == .mint)
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

    try await render(app) { store.theme != nil }
    await mainQueueTurn()

    #expect(store.theme?.colors.primary == .mint)
  }

  @Test
  func theAppIconModifiersRecordTheAppsIcon() async throws {
    let store = UpdateRequiredAppearanceStore()
    let app = Color.clear
      .clerkAppIcon(Image(systemName: "star"))
      .clerkAppIcon(maxHeight: 72)
      .environment(\.updateRequiredAppearanceRecorder, UpdateRequiredAppearanceRecorder { store })

    try await render(app) { store.appIcon != nil && store.appIconMaxHeight != nil }

    #expect(store.appIcon == Image(systemName: "star"))
    #expect(store.appIconMaxHeight == 72)
  }

  @Test
  func theUpdateWindowsOwnValuesAreNotRecorded() async throws {
    let store = UpdateRequiredAppearanceStore()
    let presented = UpdateRequiredAppearanceStore()
    presented.theme = .default
    presented.appIcon = Image(systemName: "star")
    presented.appIconMaxHeight = 72
    let window = StoreBackedProbeView(store: presented)
      .environment(\.updateRequiredAppearanceRecorder, UpdateRequiredAppearanceRecorder { store })

    try await render(window) { AppearanceProbe.primaryColor != nil }
    await mainQueueTurn()

    #expect(store.theme == nil)
    #expect(store.appIcon == nil)
    #expect(store.appIconMaxHeight == nil)
  }

  @Test
  func aLaterRecordedValueUpdatesThePresentedView() async throws {
    let store = UpdateRequiredAppearanceStore()
    let window = try await render(StoreBackedProbeView(store: store)) { AppearanceProbe.appIconMaxHeight == 44 }

    store.appIconMaxHeight = 96
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

  private func mainQueueTurn() async {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
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
    AppearanceProbeView().updateRequiredAppearance(store)
  }
}

#endif
