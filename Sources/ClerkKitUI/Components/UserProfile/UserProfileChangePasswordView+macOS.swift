//
//  UserProfileChangePasswordView+macOS.swift
//  Clerk
//

#if os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileChangePasswordView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme

  @State private var currentPassword = ""
  @State private var newPassword = ""
  @State private var confirmNewPassword = ""
  @State private var signOutOfOtherSessions = false
  @State private var isSaving = false
  @State private var errorMessage: String?

  var isAddingPassword: Bool = false

  private var user: User? {
    clerk.user
  }

  private var saveIsDisabled: Bool {
    if !isAddingPassword && currentPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return true
    }

    let trimmedNew = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedConfirm = confirmNewPassword.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedNew.isEmpty || trimmedConfirm.isEmpty || trimmedNew != trimmedConfirm
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(isAddingPassword ? "Add password" : "Update password")
        .font(theme.fonts.title3.weight(.semibold))
        .foregroundStyle(theme.colors.foreground)

      Text(isAddingPassword
        ? "Add a password so you can sign in without relying only on connected providers."
        : "Enter your current password and choose a new one.")
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 16) {
        if !isAddingPassword {
          ClerkTextField("Current password", text: $currentPassword, isSecure: true)
        }

        ClerkTextField("New password", text: $newPassword, isSecure: true)

        ClerkTextField("Confirm password", text: $confirmNewPassword, isSecure: true)
      }

      Toggle("Sign out of all other devices", isOn: $signOutOfOtherSessions)
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.foreground)
        .toggleStyle(.switch)
        .tint(theme.colors.primary)

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
        .buttonStyle(.secondary(config: .init(emphasis: .low, size: .small)))
        .keyboardShortcut(.cancelAction)

        Spacer()

        Button(isAddingPassword ? "Add Password" : "Save") {
          Task {
            await resetPassword()
          }
        }
        .buttonStyle(.primary())
        .disabled(isSaving || saveIsDisabled)
      }
    }
    .padding(24)
    .frame(minWidth: 420, maxWidth: 520, alignment: .leading)
    .background(theme.colors.background)
  }
}

extension UserProfileChangePasswordView {
  @MainActor
  private func resetPassword() async {
    guard let user else { return }

    isSaving = true
    errorMessage = nil
    defer { isSaving = false }

    do {
      try await user.updatePassword(
        .init(
          currentPassword: isAddingPassword ? nil : currentPassword,
          newPassword: newPassword,
          signOutOfOtherSessions: signOutOfOtherSessions
        )
      )

      _ = try? await clerk.refreshClient()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
      ClerkLogger.error("Failed to update password", error: error)
    }
  }
}

#Preview("Change Password") {
  UserProfileChangePasswordView()
    .environment(Clerk.preview())
}

#Preview("Add Password") {
  UserProfileChangePasswordView(isAddingPassword: true)
    .environment(Clerk.preview())
}

#endif
