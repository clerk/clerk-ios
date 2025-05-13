//
//  Badge.swift
//  Clerk
//
//  Created by Mike Pitre on 5/13/25.
//

import SwiftUI

struct Badge: View {
  @Environment(\.clerkTheme) private var theme

  enum Style: CaseIterable {
    case primary
    case secondary
    case positive
    case negative
    case warning
  }

  var foregroundColor: Color {
    switch style {
    case .primary:
      theme.colors.textOnPrimaryBackground
    case .secondary:
      theme.colors.textSecondary
    case .positive:
      theme.colors.success
    case .negative:
      theme.colors.danger
    case .warning:
      theme.colors.warning
    }
  }

  var backgroundColor: Color {
    switch style {
    case .primary:
      theme.colors.primary
    case .secondary:
      theme.colors.backgroundSecondary
    case .positive:
      theme.colors.backgroundSuccess
    case .negative:
      theme.colors.backgroundDanger
    case .warning:
      theme.colors.backgroundWarning
    }
  }

  var borderColor: Color {
    switch style {
    case .primary:
        .clear
    case .secondary:
      theme.colors.backgroundSecondary
    case .positive:
      theme.colors.success
    case .negative:
      theme.colors.danger
    case .warning:
      theme.colors.warning
    }
  }

  private let text: Text
  private let style: Style

  init(key: LocalizedStringKey, style: Style = .primary) {
    self.text = Text(key, bundle: .module)
    self.style = style
  }

  init(string: String, style: Style = .primary) {
    self.text = Text(string)
    self.style = style
  }

  var body: some View {
    text
      .font(theme.fonts.footnote)
      .frame(minHeight: 18)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 6)
      .foregroundStyle(foregroundColor)
      .background {
        if style == .secondary {
          LinearGradient(
            colors: [
              theme.colors.background,
              theme.colors.backgroundTransparent,
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        }
      }
      .background(theme.colors.backgroundSecondary)
      .background(backgroundColor)
      .clipShape(.rect(cornerRadius: theme.design.borderRadius))
      .overlay {
        RoundedRectangle(cornerRadius: theme.design.borderRadius)
          .strokeBorder(borderColor, lineWidth: 1)
      }
  }
}

#Preview {
  ForEach(Badge.Style.allCases, id: \.self) { style in
    Badge(key: "Badge Label", style: style)
  }
}
