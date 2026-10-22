//
//  UpdateRequiredView+Appearance.swift
//  Clerk
//

#if os(iOS)

import os
import SwiftUI

struct UpdateRequiredAppearance {
  var theme: ClerkTheme
  var appIcon: Image?
  var appIconMaxHeight: CGFloat
}

@MainActor
@Observable
final class UpdateRequiredAppearanceStore {
  static let shared = UpdateRequiredAppearanceStore()

  var shownTheme: ClerkTheme?
  var appliedTheme: ClerkTheme?
  var appliedAppIcon: Image?
  var appliedAppIconMaxHeight: CGFloat?

  func presentedAppearance(dashboardLogoURL: String?, bundleIcon: () -> Image? = { Image.appIcon }) -> UpdateRequiredAppearance {
    let hasDashboardLogo = !(dashboardLogoURL?.isEmpty ?? true)
    return UpdateRequiredAppearance(
      theme: shownTheme ?? appliedTheme ?? .default,
      appIcon: appliedAppIcon ?? (hasDashboardLogo ? nil : bundleIcon()),
      appIconMaxHeight: appliedAppIconMaxHeight ?? 44
    )
  }
}

extension View {
  func updateRequiredAppearance(_ appearance: UpdateRequiredAppearance) -> some View {
    environment(\.clerkThemeWithoutRecording, appearance.theme)
      .environment(\.clerkAppIcon, appearance.appIcon)
      .environment(\.clerkAppIconMaxHeight, appearance.appIconMaxHeight)
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

/// Clerk presents UpdateRequiredView in its own window, outside the app's view hierarchy, so it
/// keeps the first theme and app icon the app sets. SwiftUI builds the environment from the root
/// down, so the first value is the app's root one. SwiftUI sets environment values while it builds
/// views, so values are recorded into a lock and published to the store afterward.
enum UpdateRequiredAppearanceRecorder {
  private struct State: @unchecked Sendable {
    var theme: ClerkTheme?
    var appIcon: Image?
    var appIconMaxHeight: CGFloat?
    var publishIsScheduled = false
  }

  private static let state = OSAllocatedUnfairLock(uncheckedState: State())

  static func recordTheme(_ theme: ClerkTheme) {
    record { state in
      guard state.theme == nil else { return false }
      state.theme = theme
      return true
    }
  }

  static func recordAppIcon(_ appIcon: Image?) {
    guard let appIcon else { return }
    record { state in
      guard state.appIcon == nil else { return false }
      state.appIcon = appIcon
      return true
    }
  }

  static func recordAppIconMaxHeight(_ maxHeight: CGFloat) {
    record { state in
      guard state.appIconMaxHeight == nil else { return false }
      state.appIconMaxHeight = maxHeight
      return true
    }
  }

  static func reset() {
    state.withLockUnchecked { $0 = State() }
  }

  private static func record(_ update: (inout State) -> Bool) {
    let shouldSchedule = state.withLockUnchecked { state in
      guard update(&state), !state.publishIsScheduled else { return false }
      state.publishIsScheduled = true
      return true
    }
    guard shouldSchedule else { return }
    DispatchQueue.main.async {
      let recorded = state.withLockUnchecked { state in
        state.publishIsScheduled = false
        return state
      }
      MainActor.assumeIsolated {
        let store = UpdateRequiredAppearanceStore.shared
        store.appliedTheme = recorded.theme
        store.appliedAppIcon = recorded.appIcon
        store.appliedAppIconMaxHeight = recorded.appIconMaxHeight
      }
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
