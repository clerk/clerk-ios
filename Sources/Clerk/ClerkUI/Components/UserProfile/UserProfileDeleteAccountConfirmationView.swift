//
//  UserProfileDeleteAccountConfirmationView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/2/25.
//

#if os(iOS)

  import SwiftUI

  struct UserProfileDeleteAccountConfirmationView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.userProfileSharedState) private var sharedState

    @State private var deleteAccount = ""
    @State private var error: Error?
    @FocusState private var isFocused: Bool
    
    var user: User? {
      clerk.user
    }
    
    var buttonIsDisabled: Bool {
      deleteAccount != String(localized: "DELETE", bundle: .module)
    }

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(spacing: 24) {
            Text("Are you sure you want to delete your account? This action is permanent and irreversible.", bundle: .module)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.danger)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
              ClerkTextField("Type \"DELETE\" to continue", text: $deleteAccount)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
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
              await deleteAccount()
            } label: { isRunning in
              Text("Delete account", bundle: .module)
                .frame(maxWidth: .infinity)
                .overlayProgressView(isActive: isRunning) {
                  SpinnerView(color: theme.colors.textOnPrimaryBackground)
                }
            }
            .buttonStyle(.negative())
            .disabled(buttonIsDisabled)
          }
          .padding(24)
        }
        .background(theme.colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(theme.colors.background, for: .navigationBar)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              dismiss()
            }
            .foregroundStyle(theme.colors.primary)
          }

          ToolbarItem(placement: .principal) {
            Text("Delete account", bundle: .module)
              .font(theme.fonts.headline)
              .foregroundStyle(theme.colors.text)
          }
        }
      }
    }
  }

  extension UserProfileDeleteAccountConfirmationView {
    
    func deleteAccount() async {
      guard let user else { return }
      
      do {
        try await user.delete()
        dismiss()
        sharedState.path = NavigationPath()
        if clerk.session != nil && (clerk.client?.activeSessions ?? []).count > 1 {
          sharedState.accountSwitcherIsPresented = true
        }
      } catch {
        self.error = error
      }
    }
    
  }

  #Preview {
    UserProfileDeleteAccountConfirmationView()
      .environment(\.clerkTheme, .clerk)
      .environment(\.locale, .init(identifier: "es"))
  }

#endif
