//
//  UpdateRequiredView+Appearance.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
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

  func presentedAppearance(dashboardLogoURL: String?, bundleIcon: () -> Image? = { nil }) -> UpdateRequiredAppearance {
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
final class UpdateRequiredAppearanceRecorder: Sendable {
  enum Value: @unchecked Sendable {
    case theme(ClerkTheme)
    case appIcon(Image)
    case appIconMaxHeight(CGFloat)
  }

  private struct State: @unchecked Sendable {
    var theme: ClerkTheme?
    var appIcon: Image?
    var appIconMaxHeight: CGFloat?
    var publishIsScheduled = false
  }

  static let shared = UpdateRequiredAppearanceRecorder { UpdateRequiredAppearanceStore.shared }

  private let state = OSAllocatedUnfairLock(uncheckedState: State())
  private let store: @MainActor @Sendable () -> UpdateRequiredAppearanceStore

  init(store: @escaping @MainActor @Sendable () -> UpdateRequiredAppearanceStore) {
    self.store = store
  }

  func record(_ value: Value) {
    let shouldSchedule = state.withLockUnchecked { state in
      switch value {
      case let .theme(theme):
        guard state.theme == nil else { return false }
        state.theme = theme
      case let .appIcon(appIcon):
        guard state.appIcon == nil else { return false }
        state.appIcon = appIcon
      case let .appIconMaxHeight(maxHeight):
        guard state.appIconMaxHeight == nil else { return false }
        state.appIconMaxHeight = maxHeight
      }
      guard !state.publishIsScheduled else { return false }
      state.publishIsScheduled = true
      return true
    }
    guard shouldSchedule else { return }
    DispatchQueue.main.async { [self] in
      let recorded = state.withLockUnchecked { state in
        state.publishIsScheduled = false
        return state
      }
      MainActor.assumeIsolated {
        let store = store()
        store.appliedTheme = recorded.theme
        store.appliedAppIcon = recorded.appIcon
        store.appliedAppIconMaxHeight = recorded.appIconMaxHeight
      }
    }
  }
}

extension EnvironmentValues {
  @Entry var updateRequiredAppearanceRecorder = UpdateRequiredAppearanceRecorder.shared
}

struct ClerkAppIconModifier: ViewModifier {
  @Environment(\.updateRequiredAppearanceRecorder) private var recorder

  let appIcon: Image?

  func body(content: Content) -> some View {
    if let appIcon {
      recorder.record(.appIcon(appIcon))
    }
    return content.environment(\.clerkAppIcon, appIcon)
  }
}

struct ClerkAppIconMaxHeightModifier: ViewModifier {
  @Environment(\.updateRequiredAppearanceRecorder) private var recorder

  let maxHeight: CGFloat

  func body(content: Content) -> some View {
    recorder.record(.appIconMaxHeight(maxHeight))
    return content.environment(\.clerkAppIconMaxHeight, maxHeight)
  }
}

extension View {
  func recordsThemeForUpdateRequiredView() -> some View {
    modifier(RecordThemeForUpdateRequiredViewModifier())
  }
}

struct PresentedUpdateRequiredView: View {
  @Environment(Clerk.self) private var clerk
  private let store = UpdateRequiredAppearanceStore.shared

  var body: some View {
    UpdateRequiredView()
      .updateRequiredAppearance(
        store.presentedAppearance(dashboardLogoURL: clerk.environment?.displayConfig.logoImageUrl, bundleIcon: { Image.appIcon })
      )
  }
}

#endif

#if os(macOS)

import AppKit
import SwiftUI

extension Image {
  @MainActor static let appIcon: Image? = Image(nsImage: NSApplication.shared.applicationIconImage)
}

#elseif os(iOS)

import SwiftUI
import UIKit

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
