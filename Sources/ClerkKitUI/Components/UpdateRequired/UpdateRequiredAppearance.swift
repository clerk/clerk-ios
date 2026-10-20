//
//  UpdateRequiredAppearance.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

/// A window Clerk presents doesn't inherit the app's SwiftUI environment, so the modifiers
/// that set the theme and app icon record them here for the presented UpdateRequiredView.
@MainActor
@Observable
final class UpdateRequiredAppearance {
  static let shared = UpdateRequiredAppearance()

  var theme: ClerkTheme = .default
  var appIcon: Image?
  var appIconMaxHeight: CGFloat = 44
  var appIconView: AnyView?
  var appIconEnvironment: EnvironmentValues?

  func appIconView(colorScheme: ColorScheme) -> AnyView? {
    guard let appIconView else { return nil }
    guard let appIconEnvironment else { return appIconView }
    return AnyView(
      appIconView
        .environment(\.colorScheme, colorScheme)
        .environment(\.self, appIconEnvironment)
    )
  }
}

enum UpdateRequiredAppearanceProperty: Hashable {
  case theme
  case appIcon
  case appIconMaxHeight
  case appIconView
}

extension EnvironmentValues {
  @Entry var recordedUpdateRequiredAppearance: Set<UpdateRequiredAppearanceProperty> = []
}

extension View {
  func recordUpdateRequiredAppearance<Value: Equatable>(
    _ property: UpdateRequiredAppearanceProperty,
    value: Value,
    record: @escaping @MainActor (Value) -> Void
  ) -> some View {
    modifier(RecordAppearanceModifier(property: property, value: value, record: record))
  }

  func recordUpdateRequiredAppearanceOnAppear(
    _ property: UpdateRequiredAppearanceProperty,
    record: @escaping @MainActor (EnvironmentValues) -> Void
  ) -> some View {
    modifier(RecordAppearanceOnAppearModifier(property: property, record: record))
  }
}

private struct RecordAppearanceOnAppearModifier: ViewModifier {
  @Environment(\.self) private var environment
  @Environment(\.recordedUpdateRequiredAppearance) private var recorded

  let property: UpdateRequiredAppearanceProperty
  let record: @MainActor (EnvironmentValues) -> Void

  func body(content: Content) -> some View {
    content
      .environment(\.recordedUpdateRequiredAppearance, recorded.union([property]))
      .onAppear {
        guard !recorded.contains(property) else { return }
        record(environment)
      }
  }
}

private struct RecordAppearanceModifier<Value: Equatable>: ViewModifier {
  @Environment(\.recordedUpdateRequiredAppearance) private var recorded

  let property: UpdateRequiredAppearanceProperty
  let value: Value
  let record: @MainActor (Value) -> Void

  func body(content: Content) -> some View {
    content
      .environment(\.recordedUpdateRequiredAppearance, recorded.union([property]))
      .onChange(of: value, initial: true) { _, value in
        guard !recorded.contains(property) else { return }
        record(value)
      }
  }
}

#endif
