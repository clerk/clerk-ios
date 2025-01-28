//
//  ClerkTheme.swift
//
//
//  Created by Mike Pitre on 10/12/23.
//

#if os(iOS)

import SwiftUI

@Observable
public class ClerkTheme {
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
            danger: Color,
            linkColor: Color
        ) {
            self.primary = primary
            self.textPrimary = textPrimary
            self.textSecondary = textSecondary
            self.textTertiary = textTertiary
            self.textOnPrimaryBackground = textOnPrimaryBackground
            self.borderPrimary = borderPrimary
            self.danger = danger
            self.linkColor = linkColor
        }
        
        public var primary: Color
        public var textPrimary: Color
        public var textSecondary: Color
        public var textTertiary: Color
        public var textOnPrimaryBackground: Color
        public var borderPrimary: Color
        public var danger: Color
        public var linkColor: Color
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
            danger: Color(.clerkDanger),
            linkColor: .blue
        )
    )
    
}

#endif
