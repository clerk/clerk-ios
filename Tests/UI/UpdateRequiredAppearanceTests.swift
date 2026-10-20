#if os(iOS)

@testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct UpdateRequiredAppearanceTests {
  init() {
    let appearance = UpdateRequiredAppearance.shared
    appearance.theme = .default
    appearance.appIcon = nil
    appearance.appIconMaxHeight = 44
    appearance.appIconView = nil
    appearance.appIconEnvironment = nil
  }

  @Test
  func rootThemeIsRecordedAndANestedThemeDoesNotReplaceIt() async throws {
    let view = Color.clear
      .clerkTheme(.default)
      .padding()
      .clerkTheme(.clerk)

    let window = try await render(view) { UpdateRequiredAppearance.shared.theme == .clerk }
    try await layout(window) { false }

    #expect(UpdateRequiredAppearance.shared.theme == .clerk)
  }

  @Test
  func changingTheRootThemeUpdatesTheRecordedTheme() async throws {
    let model = ThemeModel(theme: .default)
    let window = try await render(ThemedView(model: model)) { UpdateRequiredAppearance.shared.theme == .default }

    model.theme = .clerk
    try await layout(window) { UpdateRequiredAppearance.shared.theme == .clerk }

    #expect(UpdateRequiredAppearance.shared.theme == .clerk)
  }

  @Test
  func rootAppIconIsRecorded() async throws {
    let view = Color.clear
      .clerkAppIcon(Image(systemName: "star"))
      .clerkAppIcon(maxHeight: 72)

    try await render(view) { UpdateRequiredAppearance.shared.appIconMaxHeight == 72 }

    #expect(UpdateRequiredAppearance.shared.appIcon == Image(systemName: "star"))
    #expect(UpdateRequiredAppearance.shared.appIconMaxHeight == 72)
  }

  @Test
  func rootAppIconViewIsRecorded() async throws {
    let view = Color.clear.clerkAppIconView { Image(systemName: "star") }

    try await render(view) { UpdateRequiredAppearance.shared.appIconView != nil }

    #expect(UpdateRequiredAppearance.shared.appIconView != nil)
  }

  @Test
  func appIconViewKeepsTheEnvironmentItWasDeclaredIn() async throws {
    IconProbe.renderedName = nil
    let view = Color.clear
      .clerkAppIconView { EnvironmentObjectIcon() }
      .environmentObject(IconModel(name: "star"))

    try await render(view) { UpdateRequiredAppearance.shared.appIconView != nil }

    // The update screen draws the icon in its own window, outside the app's hierarchy.
    let icon = try #require(UpdateRequiredAppearance.shared.appIconView(colorScheme: .dark))
    try await render(icon) { IconProbe.renderedName != nil }

    #expect(IconProbe.renderedName == "star")
  }

  @Test
  func appIconViewFollowsThePresentingColorScheme() async throws {
    IconProbe.renderedColorScheme = nil
    let view = Color.clear
      .clerkAppIconView { ColorSchemeIcon() }
      .environment(\.colorScheme, .light)

    try await render(view) { UpdateRequiredAppearance.shared.appIconView != nil }

    let icon = try #require(UpdateRequiredAppearance.shared.appIconView(colorScheme: .dark))
    try await render(icon) { IconProbe.renderedColorScheme != nil }

    #expect(IconProbe.renderedColorScheme == .dark)
  }

  @discardableResult
  private func render(_ view: some View, until condition: () -> Bool) async throws -> UIWindow {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = UIHostingController(rootView: view)
    window.isHidden = false
    try await layout(window, until: condition)
    window.isHidden = true
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
@Observable
private final class ThemeModel {
  var theme: ClerkTheme

  init(theme: ClerkTheme) {
    self.theme = theme
  }
}

private final class IconModel: ObservableObject {
  let name: String

  init(name: String) {
    self.name = name
  }
}

@MainActor
private enum IconProbe {
  static var renderedName: String?
  static var renderedColorScheme: ColorScheme?
}

private struct ColorSchemeIcon: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Image(systemName: "star")
      .onAppear { IconProbe.renderedColorScheme = colorScheme }
  }
}

private struct EnvironmentObjectIcon: View {
  @EnvironmentObject private var model: IconModel

  var body: some View {
    Image(systemName: model.name)
      .onAppear { IconProbe.renderedName = model.name }
  }
}

private struct ThemedView: View {
  let model: ThemeModel

  var body: some View {
    Color.clear.clerkTheme(model.theme)
  }
}

#endif
