//
//  ClerkThemes.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation
import SwiftUI

extension ClerkTheme {
  @MainActor
  public static let `default`: ClerkTheme = .init(
    colors: .default,
    fonts: .default,
    design: .default
  )

  @MainActor
  public static let clerk: ClerkTheme = .init(
    colors: .init(
      primary: Color("ClerkPrimary", bundle: .module),
      danger: Color("ClerkDanger", bundle: .module),
      primaryForeground: Color("ClerkPrimaryForeground", bundle: .module),
      neutral: Color("ClerkNeutral", bundle: .module),
      muted: Color("ClerkMuted", bundle: .module)
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

/// Create a custom environment key
private struct ClerkThemeEnvironmentKey: @preconcurrency EnvironmentKey {
  @MainActor static var defaultValue: ClerkTheme = .default
}

#endif
