//
//  ClerkGroupBoxStyle.swift
//  Clerk
//

#if os(macOS)

import SwiftUI

struct ClerkGroupBoxStyle: GroupBoxStyle {
  @Environment(\.clerkTheme) private var theme

  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      configuration.label
        .font(theme.fonts.subheadline.weight(.semibold))
        .foregroundStyle(theme.colors.foreground)

      configuration.content
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(theme.colors.muted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(theme.colors.border, lineWidth: 1)
    }
  }
}

extension GroupBoxStyle where Self == ClerkGroupBoxStyle {
  static var clerk: ClerkGroupBoxStyle {
    .init()
  }
}

#Preview {
  GroupBox("Account") {
    Text("Theme-backed macOS group box")
      .frame(maxWidth: .infinity, alignment: .leading)
  }
  .groupBoxStyle(.clerk)
  .padding()
  .environment(\.clerkTheme, .clerk)
}

#endif
