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
        // Customizable
        public var primary: Color
        public var textPrimary: Color
        public var textSecondary: Color
        public var textOnPrimaryBackground: Color = .white
        public var borderPrimary: Color
        
        // Constants
        public let gray500: Color = Color(.clerkGray500)
        public let gray700: Color = Color(.clerkGray700)
        public let red500: Color = Color(.clerkRed500)
    }
}

extension ClerkTheme {
    
    static let `default` = Self(
        colors: .init(
            primary: Color(.clerkPrimary),
            textPrimary: Color(.clerkTextPrimary),
            textSecondary: Color(.clerkTextSecondary),
            borderPrimary: Color(.systemFill)
        )
    )
    
}

struct ClerkThemeKey: EnvironmentKey {
    static let defaultValue: ClerkTheme = .default
}

extension EnvironmentValues {
  public var clerkTheme: ClerkTheme {
    get { self[ClerkThemeKey.self] }
    set { self[ClerkThemeKey.self] = newValue }
  }
}

#endif
