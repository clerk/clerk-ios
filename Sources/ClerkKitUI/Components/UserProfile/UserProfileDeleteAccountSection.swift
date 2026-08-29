//
//  UserProfileDeleteAccountSection.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileDeleteAccountSection: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(UserProfileSheetNavigation.self) private var navigation
  @Environment(UserProfileBuiltInRouter.self) private var builtInRouter

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
    .sheet(isPresented: $confirmationIsPresented) {
      UserProfileDeleteAccountConfirmationView()
        .environment(clerk)
        .environment(navigation)
        .environment(builtInRouter)
    }
  }
}

#Preview {
  UserProfileDeleteAccountSection()
    .clerkPreview()
}

#endif
