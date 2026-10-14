//
//  ClerkThemeTests.swift
//

#if os(iOS) || os(macOS)

import ClerkKitUI
import SwiftUI
import Testing

@MainActor
struct ClerkThemeTests {
  @Test
  func environmentOverrideStaysScopedToThatEnvironment() {
    var overridden = EnvironmentValues()
    overridden[keyPath: \.clerkTheme.colors.primary] = .red

    #expect(overridden.clerkTheme.colors.primary == .red)
    #expect(EnvironmentValues().clerkTheme.colors.primary == ClerkTheme.Colors.defaultPrimaryColor)
    #expect(ClerkTheme.default.colors.primary == ClerkTheme.Colors.defaultPrimaryColor)
  }

  @Test
  func derivedTokensFollowTheirBase() {
    var colors = ClerkTheme.Colors()
    colors.primary = .red
    colors.danger = .orange
    colors.success = .green
    colors.warning = .yellow
    colors.background = .black
    colors.ring = .purple

    let fresh = ClerkTheme.Colors(
      primary: .red,
      background: .black,
      danger: .orange,
      success: .green,
      warning: .yellow,
      ring: .purple
    )
    #expect(colors.primaryPressed == fresh.primaryPressed)
    #expect(colors.inputBorderFocused == fresh.inputBorderFocused)
    #expect(colors.dangerInputBorder == fresh.dangerInputBorder)
    #expect(colors.dangerInputBorderFocused == fresh.dangerInputBorderFocused)
    #expect(colors.backgroundTransparent == fresh.backgroundTransparent)
    #expect(colors.backgroundSuccess == fresh.backgroundSuccess)
    #expect(colors.borderSuccess == fresh.borderSuccess)
    #expect(colors.backgroundDanger == fresh.backgroundDanger)
    #expect(colors.borderDanger == fresh.borderDanger)
    #expect(colors.backgroundWarning == fresh.backgroundWarning)
    #expect(colors.borderWarning == fresh.borderWarning)
  }

  @Test
  func explicitDerivedTokenSurvivesBaseChange() {
    var colors = ClerkTheme.Colors()
    colors.backgroundDanger = .gray
    colors.danger = .orange

    #expect(colors.backgroundDanger == .gray)
  }

  @Test
  func fallbackTokensFollowTheirBaseUnlessProvided() {
    var following = ClerkTheme.Colors()
    following.primary = .red
    following.foreground = .blue
    #expect(following.switchTint == .red)
    #expect(following.secondaryButtonForeground == .blue)

    var provided = ClerkTheme.Colors(switchTint: .green)
    provided.secondaryButtonForeground = .mint
    provided.primary = .red
    provided.foreground = .blue
    #expect(provided.switchTint == .green)
    #expect(provided.secondaryButtonForeground == .mint)
  }
}

#endif
