//
//  UserProfilePasskeySection+macOS.swift
//  Clerk
//

#if os(macOS)

import ClerkKit
import SwiftUI

struct UserProfilePasskeySection: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var errorMessage: String?
  @State private var isCreatingPasskey = false

  private var user: User? {
    clerk.user
  }

  private var sortedPasskeys: [Passkey] {
    guard let user else { return [] }
    return user.passkeys.sorted { $0.createdAt < $1.createdAt }
  }

  var body: some View {
    GroupBox("Passkeys") {
      VStack(alignment: .leading, spacing: 16) {
        if sortedPasskeys.isEmpty {
          Text("No passkeys are currently configured for this account.")
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.mutedForeground)
        } else {
          ForEach(sortedPasskeys) { passkey in
            UserProfilePasskeyRow(passkey: passkey)
          }
        }

        if let errorMessage {
          Text(errorMessage)
            .font(theme.fonts.footnote)
            .foregroundStyle(theme.colors.danger)
            .fixedSize(horizontal: false, vertical: true)
        }

        HStack {
          Spacer()

          Button("Add Passkey") {
            Task {
              await createPasskey()
            }
          }
          .buttonStyle(.secondary(config: .init(emphasis: .low)))
          .disabled(isCreatingPasskey)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .groupBoxStyle(.clerk)
  }
}

extension UserProfilePasskeySection {
  @MainActor
  private func createPasskey() async {
    guard let user else { return }

    isCreatingPasskey = true
    errorMessage = nil
    defer { isCreatingPasskey = false }

    do {
      _ = try await user.createPasskey()
      _ = try? await clerk.refreshClient()
    } catch {
      if error.isUserCancelledError { return }
      errorMessage = error.localizedDescription
      ClerkLogger.error("Failed to create passkey", error: error)
    }
  }
}

#Preview {
  UserProfilePasskeySection()
    .environment(Clerk.preview())
}

#endif
