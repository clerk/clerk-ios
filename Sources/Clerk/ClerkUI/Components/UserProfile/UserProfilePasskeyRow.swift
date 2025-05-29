//
//  UserProfilePasskeyRow.swift
//  Clerk
//
//  Created by Mike Pitre on 5/29/25.
//

#if os(iOS)

  import SwiftUI

  struct UserProfilePasskeyRow: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme

    let passkey: Passkey

    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: passkey.name)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.text)
          .frame(minHeight: 22)

        VStack(alignment: .leading, spacing: 0) {
          Group {
            Text("Created: \(passkey.createdAt.relativeNamedFormat)", bundle: .module)
            
            if let lastUsedAt = passkey.lastUsedAt {
              Text("Last used: \(lastUsedAt.relativeNamedFormat)", bundle: .module)
            }
          }
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.textSecondary)
          .frame(minHeight: 20)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
      .overlay(alignment: .bottom) {
        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)
      }
      .buttonStyle(.pressedBackground)
      .simultaneousGesture(TapGesture())
    }
  }

  #Preview {
    UserProfilePasskeyRow(passkey: .mock)
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
