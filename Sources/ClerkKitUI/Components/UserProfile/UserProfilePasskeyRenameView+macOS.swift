//
//  UserProfilePasskeyRenameView+macOS.swift
//  Clerk
//

#if os(macOS)

import ClerkKit
import SwiftUI

struct UserProfilePasskeyRenameView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme

  @State private var passkeyName: String
  @State private var isSaving = false
  @State private var errorMessage: String?

  let passkey: Passkey

  init(passkey: Passkey) {
    self.passkey = passkey
    _passkeyName = State(initialValue: passkey.name)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Rename Passkey")
        .font(theme.fonts.title3.weight(.semibold))
        .foregroundStyle(theme.colors.foreground)

      Text("You can change the passkey name to make it easier to find.")
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)

      ClerkTextField("Name of passkey", text: $passkeyName)

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

        Button("Save") {
          Task {
            await renamePasskey()
          }
        }
        .buttonStyle(.primary())
        .disabled(isSaving || passkeyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(24)
    .frame(minWidth: 420, maxWidth: 520, alignment: .leading)
    .background(theme.colors.background)
  }
}

extension UserProfilePasskeyRenameView {
  @MainActor
  private func renamePasskey() async {
    isSaving = true
    errorMessage = nil
    defer { isSaving = false }

    do {
      try await passkey.update(name: passkeyName.trimmingCharacters(in: .whitespacesAndNewlines))
      _ = try? await clerk.refreshClient()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
      ClerkLogger.error("Failed to rename passkey", error: error)
    }
  }
}

#Preview {
  UserProfilePasskeyRenameView(passkey: .mock)
    .environment(Clerk.preview())
}

#endif
