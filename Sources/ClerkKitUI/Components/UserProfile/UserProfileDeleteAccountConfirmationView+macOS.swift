//
//  UserProfileDeleteAccountConfirmationView+macOS.swift
//  Clerk
//

#if os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileDeleteAccountConfirmationView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme

  @State private var confirmationText = ""
  @State private var errorMessage: String?
  @State private var isDeleting = false

  private var user: User? {
    clerk.user
  }

  private var buttonIsDisabled: Bool {
    confirmationText != "DELETE" || isDeleting
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Delete account")
        .font(theme.fonts.title3.weight(.semibold))
        .foregroundStyle(theme.colors.foreground)

      Text("Are you sure you want to delete your account? This action is permanent and irreversible.")
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.danger)
        .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 8) {
        Text("Type \"DELETE\" to continue")
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)

        TextField("DELETE", text: $confirmationText)
          .textFieldStyle(.roundedBorder)
      }

      if let errorMessage {
        Text(errorMessage)
          .font(theme.fonts.footnote)
          .foregroundStyle(theme.colors.danger)
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack {
        Button("Cancel") {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Spacer()

        Button("Delete Account") {
          Task {
            await deleteAccount()
          }
        }
        .buttonStyle(.negative())
        .disabled(buttonIsDisabled)
      }
    }
    .padding(24)
    .frame(minWidth: 420, maxWidth: 520, alignment: .leading)
    .background(theme.colors.background)
  }
}

extension UserProfileDeleteAccountConfirmationView {
  @MainActor
  fileprivate func deleteAccount() async {
    guard let user else { return }

    isDeleting = true
    errorMessage = nil
    defer { isDeleting = false }

    do {
      try await user.delete()
      _ = try? await clerk.refreshClient()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
      ClerkLogger.error("Failed to delete account", error: error)
    }
  }
}

#Preview {
  UserProfileDeleteAccountConfirmationView()
    .environment(Clerk.preview())
}

#endif
