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
    public var authPresentationStyle: PresentationStyle
    
    public struct Colors {
        public var primary: Color
        public var primaryButtonTextColor: Color
    }
    
    public enum PresentationStyle {
        case sheet
        case fullScreenCover
    }
}

extension ClerkTheme {
    
    static let `default` = Self(
        colors: .init(
            primary: .primary,
            primaryButtonTextColor: Color(.systemBackground)
        ),
        authPresentationStyle: .sheet
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
