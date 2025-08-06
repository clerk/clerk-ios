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
        public var input: Color
        public var danger: Color
        public var success: Color
        public var warning: Color
        public var foreground: Color
        public var mutedForeground: Color
        public var primaryForeground: Color
        public var inputForeground: Color
        public var neutral: Color
        public var ring: Color
        public var muted: Color
        public var shadow: Color
        
        // Generated
        public var primaryPressed: Color
        public var border: Color
        public var buttonBorder: Color
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
            input: Color = Self.default.input,
            danger: Color = Self.default.danger,
            success: Color = Self.default.success,
            warning: Color = Self.default.warning,
            foreground: Color = Self.default.foreground,
            mutedForeground: Color = Self.default.mutedForeground,
            primaryForeground: Color = Self.default.primaryForeground,
            inputForeground: Color = Self.default.inputForeground,
            neutral: Color = Self.default.neutral,
            ring: Color = Self.default.ring,
            muted: Color = Self.default.muted,
            shadow: Color = Self.default.shadow,
            border: Color = Self.default.border
        ) {
            self.primary = primary
            self.background = background
            self.input = input
            self.danger = danger
            self.success = success
            self.warning = warning
            self.foreground = foreground
            self.mutedForeground = mutedForeground
            self.primaryForeground = primaryForeground
            self.inputForeground = inputForeground
            self.neutral = neutral
            self.ring = ring
            self.muted = muted
            self.shadow = shadow
            
            self.primaryPressed = primary.isDark ? primary.lighten(by: 0.06) : primary.darken(by: 0.06)
            self.border = border.opacity(0.06)
            self.buttonBorder = border.opacity(0.08)
            self.inputBorder = border.opacity(0.11)
            self.inputBorderFocused = ring.opacity(0.28)
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
            input: Color(.input),
            danger: Color(.danger),
            success: Color(.success),
            warning: Color(.warning),
            foreground: Color(.foreground),
            mutedForeground: Color(.mutedForeground),
            primaryForeground: Color(.primaryForeground),
            inputForeground: Color(.inputForeground),
            neutral: Color(.neutral),
            ring: Color(.neutral),
            muted: Color(.muted),
            shadow: Color(.neutral),
            border: Color(.neutral)
        )
    }

}

#endif
