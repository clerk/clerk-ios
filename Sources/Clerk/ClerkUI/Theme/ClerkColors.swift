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
        }

        // MARK: - Generated Colors

        var primaryPressed: Color {
            primary.isDark ? primary.lighten(by: 0.06) : primary.darken(by: 0.06)
        }

        var border: Color {
            neutral.opacity(0.06)
        }

        var buttonBorder: Color {
            neutral.opacity(0.08)
        }

        var backgroundSecondary: Color {
            neutral.opacity(0.03)
        }

        var inputBorder: Color {
            neutral.opacity(0.11)
        }

        var inputBorderFocused: Color {
            neutral.opacity(0.28)
        }

        var dangerInputBorder: Color {
            danger.opacity(0.53)
        }

        var dangerInputBorderFocused: Color {
            danger.opacity(0.15)
        }

        var backgroundTransparent: Color {
            background.opacity(0.5)
        }

        var backgroundSuccess: Color {
            success.opacity(0.12)
        }

        var borderSuccess: Color {
            success.opacity(0.77)
        }

        var backgroundDanger: Color {
            danger.opacity(0.12)
        }

        var borderDanger: Color {
            danger.opacity(0.77)
        }

        var backgroundWarning: Color {
            warning.opacity(0.12)
        }

        var borderWarning: Color {
            warning.opacity(0.77)
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
