//
//  StrategyOptionButton.swift
//

#if os(iOS)

import SwiftUI

/// A bordered button label displaying an icon and text, used for strategy selection lists.
///
/// Use this as a `Button` label with `.buttonStyle(.secondary())` applied by the caller.
struct StrategyOptionButton: View {
  @Environment(\.clerkTheme) private var theme

  let iconName: String
  let text: LocalizedStringKey

  var body: some View {
    HStack(spacing: 6) {
      Image(iconName, bundle: .module)
        .resizable()
        .frame(width: 16, height: 16)
        .scaledToFit()
        .foregroundStyle(theme.colors.mutedForeground)
        .accessibilityHidden(true)
      Text(text, bundle: .module)
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.foreground)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .frame(maxWidth: .infinity)
  }
}

#endif
