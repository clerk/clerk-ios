//
//  TextDivider.swift
//  Clerk
//
//  Created by Mike Pitre on 4/11/25.
//

#if os(iOS)

import SwiftUI

struct TextDivider: View {
  @Environment(\.clerkTheme) private var theme
  
  let string: LocalizedStringKey
  
  var divider: some View {
    Rectangle()
      .foregroundStyle(theme.colors.border)
      .frame(height: 1)
  }
  
  var body: some View {
    HStack(spacing: 16) {
      divider
      Text(string, bundle: .module)
        .font(theme.fonts.footnote)
        .foregroundStyle(theme.colors.textSecondary)
        .multilineTextAlignment(.center)
        .layoutPriority(1)
      divider
    }
  }
}

#Preview {
  VStack {
    TextDivider(string: "or")
    TextDivider(string: "Or, sign in with another method")
    TextDivider(string: "Or, sign in with another method. This is some really long text.")
  }
    .padding()
}

#endif
