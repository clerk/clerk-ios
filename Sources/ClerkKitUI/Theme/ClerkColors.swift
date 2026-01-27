//
//  ClerkColors.swift
//  Clerk
//
//  Created by Mike Pitre on 4/9/25.
//

#if os(iOS)

import SwiftUI

extension ClerkTheme {
  /// A palette of semantic colors used by ClerkKitUI.
  ///
  /// Many additional tokens (such as borders and state variants) are derived
  /// from the base colors you provide here.
  public struct Colors {
    /// The primary color used throughout the views.
    public var primary: Color

    /// The background color for containers.
    public var background: Color

    /// The background color used for input fields.
    public var input: Color

    /// The color used for error states.
    public var danger: Color

    /// The color used for success states.
    public var success: Color

    /// The color used for warning states.
    public var warning: Color

    /// The color used for text.
    public var foreground: Color

    /// The color used for secondary text.
    public var mutedForeground: Color

    /// The color used for text on the primary background.
    public var primaryForeground: Color

    /// The color used for text in input fields.
    public var inputForeground: Color

    /// The color that will be used to generate the neutral shades the views use.
    public var neutral: Color

    /// The color of the ring when an interactive element is focused.
    public var ring: Color

    /// The color used for muted backgrounds.
    public var muted: Color

    /// The base shadow color used in the views.
    public var shadow: Color

    // MARK: - Generated Colors

    /// A pressed-state variant of `primary`.
    public var primaryPressed: Color

    /// The base border color used in the views.
    public var border: Color

    /// A slightly stronger border color for buttons.
    public var buttonBorder: Color

    /// The default border color for input fields.
    public var inputBorder: Color

    /// The focused border color for input fields.
    public var inputBorderFocused: Color

    /// The default error border color for input fields.
    public var dangerInputBorder: Color

    /// The focused error border color for input fields.
    public var dangerInputBorderFocused: Color

    /// A translucent background color for overlays.
    public var backgroundTransparent: Color

    /// A success background tint.
    public var backgroundSuccess: Color

    /// A success border tint.
    public var borderSuccess: Color

    /// An error background tint.
    public var backgroundDanger: Color

    /// An error border tint.
    public var borderDanger: Color

    /// A warning background tint.
    public var backgroundWarning: Color

    /// A warning border tint.
    public var borderWarning: Color

    /// Creates a semantic color palette and derives ClerkKitUI state colors.
    ///
    /// - Note: Derived tokens are computed from the provided base colors, including
    ///   the `border` base color passed to this initializer.
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

      // Derived tokens
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

extension ClerkTheme.Colors {
  public static let defaultPrimaryColor = Color(.primary)
  public static let defaultBackgroundColor = Color(.background)
  public static let defaultInputColor = Color(.input)
  public static let defaultDangerColor = Color(.danger)
  public static let defaultSuccessColor = Color(.success)
  public static let defaultWarningColor = Color(.warning)
  public static let defaultForegroundColor = Color(.foreground)
  public static let defaultMutedForegroundColor = Color(.mutedForeground)
  public static let defaultPrimaryForegroundColor = Color(.primaryForeground)
  public static let defaultInputForegroundColor = Color(.inputForeground)
  public static let defaultNeutralColor = Color(.neutral)
  public static let defaultRingColor = Color(.neutral)
  public static let defaultMutedColor = Color(.muted)
  public static let defaultShadowColor = Color(.neutral)
  public static let defaultBorderColor = Color(.neutral)

  /// The default ClerkKitUI semantic color palette.
  public nonisolated static var `default`: Self {
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
