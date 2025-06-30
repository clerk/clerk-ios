//
//  UserProfilePasskeyRenameView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/30/25.
//

#if os(iOS)

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
              .foregroundStyle(theme.colors.textSecondary)
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
                  SpinnerView(color: theme.colors.textOnPrimaryBackground)
                }
            }
            .buttonStyle(.primary())
          }
          .padding(24)
        }
        .background(theme.colors.background)
        .presentationBackground(theme.colors.background)
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
              .foregroundStyle(theme.colors.text)
          }
        }
      }
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
