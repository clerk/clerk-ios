//
//  TextDivider.swift
//  Clerk
//
//  Created by Mike Pitre on 4/11/25.
//

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
      divider
    }
  }
}

#Preview {
  TextDivider(string: "or")
    .padding()
}
