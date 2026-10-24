//
//  UpdateRequiredView+Appearance.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import os
import SwiftUI

@MainActor
@Observable
final class UpdateRequiredAppearanceStore {
  static let shared = UpdateRequiredAppearanceStore()

  var theme: ClerkTheme?
  var appIcon: Image?
  var appIconMaxHeight: CGFloat?
}

extension View {
  func updateRequiredAppearance(_ store: UpdateRequiredAppearanceStore) -> some View {
    environment(\.clerkThemeWithoutRecording, store.theme ?? .default)
      .environment(\.clerkAppIcon, store.appIcon)
      .environment(\.clerkAppIconMaxHeight, store.appIconMaxHeight ?? EnvironmentValues().clerkAppIconMaxHeight)
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
        store.theme = recorded.theme
        store.appIcon = recorded.appIcon
        store.appIconMaxHeight = recorded.appIconMaxHeight
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

struct PresentedUpdateRequiredView: View {
  var body: some View {
    UpdateRequiredView()
      .updateRequiredAppearance(.shared)
  }
}

#endif
