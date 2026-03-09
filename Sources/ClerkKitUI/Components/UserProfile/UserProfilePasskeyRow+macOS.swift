//
//  UserProfilePasskeyRow+macOS.swift
//  Clerk
//

#if os(macOS)

import ClerkKit
import SwiftUI

struct UserProfilePasskeyRow: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var renameIsPresented = false
  @State private var isConfirmingRemoval = false
  @State private var isLoading = false
  @State private var errorMessage: String?

  let passkey: Passkey

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(verbatim: passkey.name)
            .font(theme.fonts.subheadline.weight(.medium))
            .foregroundStyle(theme.colors.foreground)

          Text("Created: \(passkey.createdAt.relativeNamedFormat)")
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.mutedForeground)

          if let lastUsedAt = passkey.lastUsedAt {
            Text("Last used: \(lastUsedAt.relativeNamedFormat)")
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.mutedForeground)
          }
        }

        Spacer()

        Menu("Actions") {
          Button("Rename") {
            renameIsPresented = true
          }

          Button("Remove", role: .destructive) {
            isConfirmingRemoval = true
          }
        }
        .menuStyle(.borderlessButton)
        .disabled(isLoading)
      }

      if let errorMessage {
        Text(errorMessage)
          .font(theme.fonts.footnote)
          .foregroundStyle(theme.colors.danger)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .sheet(isPresented: $renameIsPresented) {
      UserProfilePasskeyRenameView(passkey: passkey)
    }
    .alert("Remove passkey?", isPresented: $isConfirmingRemoval) {
      Button("Remove", role: .destructive) {
        Task {
          await removePasskey()
        }
      }

      Button("Cancel", role: .cancel) {}
    } message: {
      Text("\(passkey.name) will be removed from this account. You will no longer be able to sign in using this passkey.")
    }
  }
}

extension UserProfilePasskeyRow {
  @MainActor
  private func removePasskey() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      try await passkey.delete()
      _ = try? await clerk.refreshClient()
    } catch {
      errorMessage = error.localizedDescription
      ClerkLogger.error("Failed to remove passkey", error: error)
    }
  }
}

#Preview {
  UserProfilePasskeyRow(passkey: .mock)
    .environment(Clerk.preview())
    .padding()
}

#endif
