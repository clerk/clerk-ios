//
//  ClerkTheme.swift
//
//
//  Created by Mike Pitre on 10/12/23.
//

#if canImport(UIKit)

import SwiftUI

public struct ClerkTheme: @unchecked Sendable {
    public init(colors: ClerkTheme.Colors) {
        self.colors = colors
    }
    
    public var colors: Colors
    
    public struct Colors: Sendable {
        public init(
            primary: Color,
            textPrimary: Color,
            textSecondary: Color,
            textTertiary: Color,
            textOnPrimaryBackground: Color,
            borderPrimary: Color,
            danger: Color
        ) {
            self.primary = primary
            self.textPrimary = textPrimary
            self.textSecondary = textSecondary
            self.textTertiary = textTertiary
            self.textOnPrimaryBackground = textOnPrimaryBackground
            self.borderPrimary = borderPrimary
            self.danger = danger
        }
        
        public var primary: Color
        public var textPrimary: Color
        public var textSecondary: Color
        public var textTertiary: Color
        public var textOnPrimaryBackground: Color
        public var borderPrimary: Color
        public var danger: Color
    }
}

extension ClerkTheme {
    
    static public let clerkDefault = ClerkTheme(
        colors: .init(
            primary: Color(.clerkPrimary),
            textPrimary: Color(.clerkTextPrimary),
            textSecondary: Color(.clerkTextSecondary),
            textTertiary: Color(.clerkTextTertiary),
            textOnPrimaryBackground: .white,
            borderPrimary: Color(.systemFill),
            danger: Color(.clerkDanger)
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
