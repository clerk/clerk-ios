//
//  ClerkThemes.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation
import SwiftUI

extension ClerkTheme {
  public static let `default`: ClerkTheme = .init(
    colors: .default,
    fonts: .default,
    design: .default
  )

  public static let clerk: ClerkTheme = .init(
    colors: .init(
      primary: Color(.clerkPrimary),
      danger: Color(.clerkDanger),
      primaryForeground: Color(.clerkPrimaryForeground),
      neutral: Color(.clerkNeutral),
      muted: Color(.clerkMuted)
    ),
    design: .init(
      borderRadius: 8.0
    )
  )
}

extension EnvironmentValues {
  public var clerkTheme: ClerkTheme {
    get { self[ClerkThemeEnvironmentKey.self] }
    set { self[ClerkThemeEnvironmentKey.self] = newValue }
  }
}

private struct ClerkThemeEnvironmentKey: EnvironmentKey {
  static let defaultValue: ClerkTheme = .default
}

#endif
