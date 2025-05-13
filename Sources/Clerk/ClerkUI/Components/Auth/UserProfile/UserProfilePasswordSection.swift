//
//  UserProfilePasswordRow.swift
//  Clerk
//
//  Created by Mike Pitre on 5/12/25.
//

import Foundation
import SwiftUI

struct UserProfilePasswordSection: View {
  @Environment(\.clerkTheme) private var theme

  var body: some View {
    Section {
      AsyncButton {
        // change password
      } label: { isRunning in
        HStack(spacing: 0) {
          HStack(alignment: .top, spacing: 16) {
            Image("icon-lock", bundle: .module)
              .resizable()
              .scaledToFit()
              .frame(width: 24, height: 24)
              .foregroundStyle(theme.colors.textSecondary)
            VStack(alignment: .leading, spacing: 4) {
              Text("Change password", bundle: .module)
                .font(theme.fonts.body)
                .foregroundStyle(theme.colors.text)
                .frame(minHeight: 22)
              Text(verbatim: "•••••••••••••••••••••••••")
                .font(theme.fonts.subheadline)
                .foregroundStyle(theme.colors.textSecondary)
                .frame(minHeight: 20)
            }
          }

          Spacer()

          Image("icon-chevron-right", bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .foregroundStyle(theme.colors.primary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .overlayProgressView(isActive: isRunning)
      }
      .overlay(alignment: .bottom) {
        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)
      }
      .background(theme.colors.background)
      .buttonStyle(.pressedBackground)
      .simultaneousGesture(TapGesture())
    } header: {
      UserProfileSectionHeader(text: "PASSWORD")
    }
  }
}

#Preview {
  UserProfilePasswordSection()
}
