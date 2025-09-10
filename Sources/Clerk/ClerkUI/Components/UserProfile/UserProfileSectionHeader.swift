//
//  UserProfileSectionHeader.swift
//  Clerk
//
//  Created by Mike Pitre on 5/9/25.
//

#if os(iOS)

import SwiftUI

struct UserProfileSectionHeader: View {
  @Environment(\.clerkTheme) private var theme

  let text: LocalizedStringKey

  var body: some View {
    Text(text, bundle: .module)
      .font(theme.fonts.caption)
      .fontWeight(.medium)
      .foregroundStyle(theme.colors.mutedForeground)
      .frame(minHeight: 16)
      .padding(.horizontal, 24)
      .padding(.top, 32)
      .padding(.bottom, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(alignment: .bottom) {
        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)
      }
  }
}

#Preview {
  @Previewable @Environment(\.clerkTheme) var theme

  UserProfileSectionHeader(text: "EMAIL ADDRESSES")
    .background(theme.colors.muted)
}

#endif
