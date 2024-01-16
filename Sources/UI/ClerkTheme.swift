//
//  ClerkTheme.swift
//
//
//  Created by Mike Pitre on 10/12/23.
//

#if canImport(UIKit)

import SwiftUI

public struct ClerkTheme {
    public var colors: Colors
    
    public struct Colors {
        public var primary: Color
        public var textPrimary: Color
        public var textSecondary: Color
        public var textOnPrimaryBackground: Color
        public var borderPrimary: Color
        public var danger: Color
    }
}

extension ClerkTheme {
    
    static let clerkDefault = Self(
        colors: .init(
            primary: Color(.clerkPrimary),
            textPrimary: Color(.clerkTextPrimary),
            textSecondary: Color(.clerkTextSecondary),
            textOnPrimaryBackground: .white,
            borderPrimary: Color(.systemFill),
            danger: Color(.clerkRed500)
        )
    )
    
}

struct ClerkThemeKey: EnvironmentKey {
    static let defaultValue: ClerkTheme = .clerkDefault
}

extension EnvironmentValues {
  public var clerkTheme: ClerkTheme {
    get { self[ClerkThemeKey.self] }
    set { self[ClerkThemeKey.self] = newValue }
  }
}

#endif
