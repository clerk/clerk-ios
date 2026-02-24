//
//  CopyableTextView.swift
//

#if os(iOS)

import SwiftUI

struct CopyableTextView: View {
  @Environment(\.clerkTheme) private var theme

  let text: String

  var body: some View {
    Text(verbatim: text)
      .font(theme.fonts.subheadline)
      .foregroundStyle(theme.colors.foreground)
      .frame(maxWidth: .infinity, minHeight: 20)
      .lineLimit(1)
      .padding(.vertical, 18)
      .padding(.horizontal, 16)
      .background(theme.colors.muted)
      .clipShape(.rect(cornerRadius: theme.design.borderRadius))
      .overlay {
        RoundedRectangle(cornerRadius: theme.design.borderRadius)
          .strokeBorder(theme.colors.border, lineWidth: 1)
      }
  }
}

#endif
