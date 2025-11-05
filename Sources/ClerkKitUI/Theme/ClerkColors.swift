//
//  ClerkColors.swift
//  Clerk
//
//  Created by Mike Pitre on 4/9/25.
//

#if os(iOS)

import SwiftUI

public extension ClerkTheme {
  struct Colors {
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

    // Generated Colors
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
      primary: Color = Self.defaultPrimaryColor,
      background: Color = Self.defaultBackgroundColor,
      input: Color = Self.defaultInputColor,
      danger: Color = Self.defaultDangerColor,
      success: Color = Self.defaultSuccessColor,
      warning: Color = Self.defaultWarningColor,
      foreground: Color = Self.defaultForegroundColor,
      mutedForeground: Color = Self.defaultMutedForegroundColor,
      primaryForeground: Color = Self.defaultPrimaryForegroundColor,
      inputForeground: Color = Self.defaultInputForegroundColor,
      neutral: Color = Self.defaultNeutralColor,
      ring: Color = Self.defaultRingColor,
      muted: Color = Self.defaultMutedColor,
      shadow: Color = Self.defaultShadowColor,
      border: Color = Self.defaultBorderColor
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

      // Generated Colors
      primaryPressed = primary.isDark ? primary.lighten(by: 0.06) : primary.darken(by: 0.06)
      self.border = border.opacity(0.06)
      buttonBorder = border.opacity(0.08)
      inputBorder = border.opacity(0.11)
      inputBorderFocused = ring.opacity(0.28)
      dangerInputBorder = danger.opacity(0.53)
      dangerInputBorderFocused = danger.opacity(0.15)
      backgroundTransparent = background.opacity(0.5)
      backgroundSuccess = success.opacity(0.12)
      borderSuccess = success.opacity(0.77)
      backgroundDanger = danger.opacity(0.12)
      borderDanger = danger.opacity(0.77)
      backgroundWarning = warning.opacity(0.12)
      borderWarning = warning.opacity(0.77)
    }
  }
}

public extension ClerkTheme.Colors {
  // Static properties for default colors to avoid circular reference
  static let defaultPrimaryColor = Color(.primary)
  static let defaultBackgroundColor = Color(.background)
  static let defaultInputColor = Color(.input)
  static let defaultDangerColor = Color(.danger)
  static let defaultSuccessColor = Color(.success)
  static let defaultWarningColor = Color(.warning)
  static let defaultForegroundColor = Color(.foreground)
  static let defaultMutedForegroundColor = Color(.mutedForeground)
  static let defaultPrimaryForegroundColor = Color(.primaryForeground)
  static let defaultInputForegroundColor = Color(.inputForeground)
  static let defaultNeutralColor = Color(.neutral)
  static let defaultRingColor = Color(.neutral)
  static let defaultMutedColor = Color(.muted)
  static let defaultShadowColor = Color(.neutral)
  static let defaultBorderColor = Color(.neutral)

  nonisolated static var `default`: Self {
    .init(
      primary: defaultPrimaryColor,
      background: defaultBackgroundColor,
      input: defaultInputColor,
      danger: defaultDangerColor,
      success: defaultSuccessColor,
      warning: defaultWarningColor,
      foreground: defaultForegroundColor,
      mutedForeground: defaultMutedForegroundColor,
      primaryForeground: defaultPrimaryForegroundColor,
      inputForeground: defaultInputForegroundColor,
      neutral: defaultNeutralColor,
      ring: defaultRingColor,
      muted: defaultMutedColor,
      shadow: defaultShadowColor,
      border: defaultBorderColor
    )
  }
}

#endif
