//
//  UserProfileDeleteAccountSection.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileDeleteAccountSection: View {
  @Environment(\.clerkTheme) private var theme

  @State private var confirmationIsPresented = false

  var body: some View {
    Section {
      UserProfileButtonRow(
        text: "Delete account",
        style: .danger,
        accessibilityIdentifier: ClerkAccessibilityIdentifiers.UserProfile.Security.deleteAccount
      ) {
        confirmationIsPresented = true
      }
      .background(theme.colors.background)
    } header: {
      UserProfileSectionHeader(text: "DELETE ACCOUNT")
    }
    .clerkSheet(isPresented: $confirmationIsPresented) {
      UserProfileDeleteAccountConfirmationView()
    }
  }
}

#Preview {
  UserProfileDeleteAccountSection()
    .environment(
      UserProfileBuiltInRouter(
        push: { _ in },
        dismissAction: { _ in }
      )
    )
    .clerkPreview()
}

#endif
