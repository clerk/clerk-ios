//
//  ClerkColors.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

extension ClerkTheme {
  /// A palette of semantic colors used by ClerkKitUI.
  ///
  /// Many additional tokens (such as borders and state variants) are derived
  /// from the base colors you provide here. A derived token follows its base
  /// color until you set it explicitly.
  public struct Colors: Sendable {
    /// The primary color used throughout the views.
    public var primary: Color

    /// The selected tint color for switch-style toggles.
    public var switchTint: Color {
      get { switchTintOverride ?? primary }
      set { switchTintOverride = newValue }
    }

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

    /// The background color for secondary buttons, including social and SSO buttons.
    public var secondaryButtonBackground: Color

    /// The color used for text and tintable icons on secondary buttons.
    public var secondaryButtonForeground: Color {
      get { secondaryButtonForegroundOverride ?? foreground }
      set { secondaryButtonForegroundOverride = newValue }
    }

    /// The base shadow color used in the views.
    public var shadow: Color

    // MARK: - Generated Colors

    /// A pressed-state variant of `primary`.
    public var primaryPressed: Color {
      get { primaryPressedOverride ?? (primary.isDark ? primary.lighten(by: 0.06) : primary.darken(by: 0.06)) }
      set { primaryPressedOverride = newValue }
    }

    /// The base border color used in the views.
    public var border: Color {
      get { borderOverride ?? baseBorder.opacity(0.06) }
      set { borderOverride = newValue }
    }

    /// A slightly stronger border color for buttons.
    public var buttonBorder: Color {
      get { buttonBorderOverride ?? baseBorder.opacity(0.08) }
      set { buttonBorderOverride = newValue }
    }

    /// The default border color for input fields.
    public var inputBorder: Color {
      get { inputBorderOverride ?? baseBorder.opacity(0.11) }
      set { inputBorderOverride = newValue }
    }

    /// The focused border color for input fields.
    public var inputBorderFocused: Color {
      get { inputBorderFocusedOverride ?? ring.opacity(0.28) }
      set { inputBorderFocusedOverride = newValue }
    }

    /// The default error border color for input fields.
    public var dangerInputBorder: Color {
      get { dangerInputBorderOverride ?? danger.opacity(0.53) }
      set { dangerInputBorderOverride = newValue }
    }

    /// The focused error border color for input fields.
    public var dangerInputBorderFocused: Color {
      get { dangerInputBorderFocusedOverride ?? danger.opacity(0.15) }
      set { dangerInputBorderFocusedOverride = newValue }
    }

    /// A translucent background color for overlays.
    public var backgroundTransparent: Color {
      get { backgroundTransparentOverride ?? background.opacity(0.5) }
      set { backgroundTransparentOverride = newValue }
    }

    /// A success background tint.
    public var backgroundSuccess: Color {
      get { backgroundSuccessOverride ?? success.opacity(0.12) }
      set { backgroundSuccessOverride = newValue }
    }

    /// A success border tint.
    public var borderSuccess: Color {
      get { borderSuccessOverride ?? success.opacity(0.77) }
      set { borderSuccessOverride = newValue }
    }

    /// An error background tint.
    public var backgroundDanger: Color {
      get { backgroundDangerOverride ?? danger.opacity(0.12) }
      set { backgroundDangerOverride = newValue }
    }

    /// An error border tint.
    public var borderDanger: Color {
      get { borderDangerOverride ?? danger.opacity(0.77) }
      set { borderDangerOverride = newValue }
    }

    /// A warning background tint.
    public var backgroundWarning: Color {
      get { backgroundWarningOverride ?? warning.opacity(0.12) }
      set { backgroundWarningOverride = newValue }
    }

    /// A warning border tint.
    public var borderWarning: Color {
      get { borderWarningOverride ?? warning.opacity(0.77) }
      set { borderWarningOverride = newValue }
    }

    private var baseBorder: Color
    private var switchTintOverride: Color?
    private var secondaryButtonForegroundOverride: Color?
    private var primaryPressedOverride: Color?
    private var borderOverride: Color?
    private var buttonBorderOverride: Color?
    private var inputBorderOverride: Color?
    private var inputBorderFocusedOverride: Color?
    private var dangerInputBorderOverride: Color?
    private var dangerInputBorderFocusedOverride: Color?
    private var backgroundTransparentOverride: Color?
    private var backgroundSuccessOverride: Color?
    private var borderSuccessOverride: Color?
    private var backgroundDangerOverride: Color?
    private var borderDangerOverride: Color?
    private var backgroundWarningOverride: Color?
    private var borderWarningOverride: Color?

    /// Creates a semantic color palette and derives ClerkKitUI state colors.
    ///
    /// - Note: Derived tokens are computed from the provided base colors, including
    ///   the `border` base color passed to this initializer.
    public init(
      primary: Color = Self.defaultPrimaryColor,
      switchTint: Color? = nil,
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
      secondaryButtonBackground: Color = Self.defaultSecondaryButtonBackgroundColor,
      secondaryButtonForeground: Color? = nil,
      shadow: Color = Self.defaultShadowColor,
      border: Color = Self.defaultBorderColor
    ) {
      self.primary = primary
      switchTintOverride = switchTint
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
      self.secondaryButtonBackground = secondaryButtonBackground
      secondaryButtonForegroundOverride = secondaryButtonForeground
      self.shadow = shadow
      baseBorder = border
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
  public static let defaultSecondaryButtonBackgroundColor = Color(.background)
  public static let defaultShadowColor = Color(.neutral)
  public static let defaultBorderColor = Color(.neutral)

  /// The default ClerkKitUI semantic color palette.
  public static var `default`: Self {
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
      secondaryButtonBackground: defaultSecondaryButtonBackgroundColor,
      shadow: defaultShadowColor,
      border: defaultBorderColor
    )
  }
}

#endif
