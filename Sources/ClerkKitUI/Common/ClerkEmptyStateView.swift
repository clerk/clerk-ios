//
//  ClerkEmptyStateView.swift
//

#if os(iOS)

import SwiftUI

struct ClerkEmptyStateView: View {
  @Environment(\.clerkTheme) private var theme

  private let icon: Icon?
  private let title: LocalizedStringKey
  private let subtitle: LocalizedStringKey?

  init(
    icon: Icon? = nil,
    title: LocalizedStringKey,
    subtitle: LocalizedStringKey? = nil
  ) {
    self.icon = icon
    self.title = title
    self.subtitle = subtitle
  }

  var body: some View {
    VStack(spacing: 12) {
      if let icon {
        icon.image
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .frame(width: icon.size, height: icon.size)
          .foregroundStyle(theme.colors.mutedForeground)
          .accessibilityHidden(true)
          .frame(width: 48, height: 48)
          .background(theme.colors.neutral.opacity(0.03))
          .clipShape(.rect(cornerRadius: 12))
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .strokeBorder(theme.colors.border, lineWidth: 1)
          }
      }

      VStack(spacing: 4) {
        Text(title, bundle: .module)
          .font(theme.fonts.headline)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.foreground)

        if let subtitle {
          Text(subtitle, bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .frame(maxWidth: 302)
        }
      }
      .multilineTextAlignment(.center)
    }
    .accessibilityElement(children: .combine)
  }
}

extension ClerkEmptyStateView {
  struct Icon {
    let image: Image
    let size: CGFloat

    static func asset(_ name: String, size: CGFloat = 20) -> Self {
      .init(image: Image(name, bundle: .module), size: size)
    }

    static func system(_ name: String, size: CGFloat = 16) -> Self {
      .init(image: Image(systemName: name), size: size)
    }
  }
}

#endif
