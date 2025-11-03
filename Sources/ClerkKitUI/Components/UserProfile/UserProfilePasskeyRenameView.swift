//
//  UserProfilePasskeyRenameView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/30/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct UserProfilePasskeyRenameView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  @State private var passkeyName: String
  @State private var error: Error?
  @FocusState private var isFocused: Bool

  let passkey: Passkey

  init(passkey: Passkey) {
    self.passkey = passkey
    self._passkeyName = State(initialValue: passkey.name)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          Text("You can change the passkey name to make it easier to find.", bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)

          VStack(spacing: 4) {
            ClerkTextField("Name of passkey", text: $passkeyName)
              .focused($isFocused)
              .onFirstAppear {
                isFocused = true
              }

            if let error {
              ErrorText(error: error, alignment: .leading)
                .font(theme.fonts.subheadline)
                .transition(.blurReplace.animation(.default))
                .id(error.localizedDescription)
            }
          }

          AsyncButton {
            await renamePasskey()
          } label: { isRunning in
            Text("Save", bundle: .module)
              .frame(maxWidth: .infinity)
              .overlayProgressView(isActive: isRunning) {
                SpinnerView(color: theme.colors.primaryForeground)
              }
          }
          .buttonStyle(.primary())
        }
        .padding(24)
      }
      .navigationBarTitleDisplayMode(.inline)
      .preGlassSolidNavBar()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundStyle(theme.colors.primary)
        }

        ToolbarItem(placement: .principal) {
          Text("Rename passkey", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
    .presentationBackground(theme.colors.background)
    .background(theme.colors.background)
  }
}

extension UserProfilePasskeyRenameView {

  func renamePasskey() async {
    do {
      try await passkey.update(name: passkeyName)
      dismiss()
    } catch {
      self.error = error
      ClerkLogger.error("Failed to rename passkey", error: error)
    }
  }

}

#Preview {
  UserProfilePasskeyRenameView(passkey: .mock)
    .environment(\.clerkTheme, .clerk)
}

#endif
