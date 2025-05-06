//
//  UserButtonPopoverRow.swift
//  Clerk
//
//  Created by Mike Pitre on 5/6/25.
//

import SwiftUI

struct UserButtonPopoverRow: View {
    @Environment(\.clerkTheme) private var theme

    let icon: String
    let text: LocalizedStringKey

    var body: some View {
      HStack(spacing: 16) {
        Image(icon, bundle: .module)
          .frame(width: 48, height: 24)
          .scaledToFit()
          .foregroundStyle(theme.colors.textSecondary)
        Text(text, bundle: .module)
          .font(theme.fonts.body)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.text)
          .frame(minHeight: 22)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 16)
      .padding(.horizontal, 24)
      .contentShape(.rect)
    }
  }

#Preview {
  UserButtonPopoverRow(icon: "icon-switch", text: "Switch account")
}
