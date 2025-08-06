//
//  ClerkColors.swift
//  Clerk
//
//  Created by Mike Pitre on 4/9/25.
//

#if os(iOS)

import SwiftUI

extension ClerkTheme {
    public struct Colors {

        public var primary: Color
        public var background: Color
        public var inputBackground: Color
        public var danger: Color
        public var success: Color
        public var warning: Color
        public var text: Color
        public var textSecondary: Color
        public var textOnPrimaryBackground: Color
        public var inputText: Color
        public var neutral: Color
        
        // Generated
        public var primaryPressed: Color
        public var border: Color
        public var buttonBorder: Color
        public var backgroundSecondary: Color
        public var inputBorder: Color
        public var inputBorderFocused: Color
        public var dangerInputBorder: Color
        public var dangerInputBorderFocused: Color
        public var backgroundTransparent: Color
        public var backgroundSuccess: Color
        public var borderSuccess: Color
        public var backgroundDanger: Color
        public var borderDanger: Color
        public var backgroundWarning: Color
        public var borderWarning: Color

        public init(
            primary: Color = Self.default.primary,
            background: Color = Self.default.background,
            inputBackground: Color = Self.default.inputBackground,
            danger: Color = Self.default.danger,
            success: Color = Self.default.success,
            warning: Color = Self.default.warning,
            text: Color = Self.default.text,
            textSecondary: Color = Self.default.textSecondary,
            textOnPrimaryBackground: Color = Self.default.textOnPrimaryBackground,
            inputText: Color = Self.default.inputText,
            neutral: Color = Self.default.neutral
        ) {
            self.primary = primary
            self.background = background
            self.inputBackground = inputBackground
            self.danger = danger
            self.success = success
            self.warning = warning
            self.text = text
            self.textSecondary = textSecondary
            self.textOnPrimaryBackground = textOnPrimaryBackground
            self.inputText = inputText
            self.neutral = neutral
            
            self.primaryPressed = primary.isDark ? primary.lighten(by: 0.06) : primary.darken(by: 0.06)
            self.border = neutral.opacity(0.06)
            self.buttonBorder = neutral.opacity(0.08)
            self.backgroundSecondary = neutral.opacity(0.03)
            self.inputBorder = neutral.opacity(0.11)
            self.inputBorderFocused = neutral.opacity(0.28)
            self.dangerInputBorder = danger.opacity(0.53)
            self.dangerInputBorderFocused = danger.opacity(0.15)
            self.backgroundTransparent = background.opacity(0.5)
            self.backgroundSuccess = success.opacity(0.12)
            self.borderSuccess = success.opacity(0.77)
            self.backgroundDanger = danger.opacity(0.12)
            self.borderDanger = danger.opacity(0.77)
            self.backgroundWarning = warning.opacity(0.12)
            self.borderWarning = warning.opacity(0.77)
        }
    }
}

extension ClerkTheme.Colors {

    public nonisolated static var `default`: Self {
        .init(
            primary: Color(.primary),
            background: Color(.background),
            inputBackground: Color(.inputBackground),
            danger: Color(.danger),
            success: Color(.success),
            warning: Color(.warning),
            text: Color(.text),
            textSecondary: Color(.textSecondary),
            textOnPrimaryBackground: Color(.textOnPrimaryBackground),
            inputText: Color(.inputText),
            neutral: Color(.neutral)
        )
    }

}

#endif
