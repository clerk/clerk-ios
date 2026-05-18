//
//  ClerkEmptyStateView.swift
//

#if os(iOS)

import SwiftUI

struct ClerkEmptyStateView: View {
  @Environment(\.clerkTheme) private var theme

  let icon: String
  let title: LocalizedStringKey
  let subtitle: LocalizedStringKey

  init(
    icon: String,
    title: LocalizedStringKey,
    subtitle: LocalizedStringKey
  ) {
    self.icon = icon
    self.title = title
    self.subtitle = subtitle
  }

  var body: some View {
    VStack(spacing: 12) {
      Image(icon, bundle: .module)
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 20, height: 20)
        .foregroundStyle(theme.colors.mutedForeground)
        .accessibilityHidden(true)
        .frame(width: 48, height: 48)
        .background(theme.colors.neutral.opacity(0.03))
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(theme.colors.border, lineWidth: 1)
        }

      VStack(spacing: 4) {
        Text(title, bundle: .module)
          .font(theme.fonts.headline)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.foreground)

        Text(subtitle, bundle: .module)
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)
          .frame(maxWidth: 302)
      }
      .multilineTextAlignment(.center)
    }
    .accessibilityElement(children: .combine)
  }
}

#endif
