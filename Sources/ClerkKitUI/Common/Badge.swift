//
//  Badge.swift
//  Clerk
//
//  Created by Mike Pitre on 5/13/25.
//

#if os(iOS)

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
      theme.colors.primaryForeground
    case .secondary:
      theme.colors.mutedForeground
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
      theme.colors.muted
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
      theme.colors.muted
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
    text = Text(key, bundle: .module)
    self.style = style
  }

  init(string: String, style: Style = .primary) {
    text = Text(string)
    self.style = style
  }

  var body: some View {
    text
      .font(theme.fonts.footnote)
      .fontWeight(.semibold)
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
      .background(theme.colors.muted)
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

// MARK: - Last Used Auth Badge Modifier

extension View {
  func lastUsedAuthBadgeOverlay(_ isVisible: Bool) -> some View {
    overlay(alignment: .topTrailing) {
      if isVisible {
        Badge(key: "Last Used", style: .secondary)
          .padding(.trailing, 8)
          .visualEffect { content, proxy in
            content.offset(y: -proxy.size.height / 2)
          }
      }
    }
  }
}

#endif
