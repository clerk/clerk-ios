//
//  UserProfileDeleteAccountConfirmationView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileDeleteAccountConfirmationView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(UserProfileSheetNavigation.self) private var navigation
  @Environment(UserProfileBuiltInRouter.self) private var builtInRouter

  @State private var deleteAccount = ""
  @State private var error: Error?
  @FocusState private var isFocused: Bool

  private var user: User? {
    clerk.user
  }

  private var buttonIsDisabled: Bool {
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
            ClerkTextField(
              "Type \"DELETE\" to continue",
              text: $deleteAccount,
              accessibilityIdentifier: ClerkAccessibilityIdentifiers.UserProfile.DeleteAccount.confirmation
            )
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.characters)
            #endif
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
                SpinnerView(color: theme.colors.primaryForeground)
              }
          }
          .buttonStyle(.negative())
          .disabled(buttonIsDisabled)
          .accessibilityIdentifier(ClerkAccessibilityIdentifiers.UserProfile.DeleteAccount.confirmButton)
        }
        .padding(24)
      }
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .preGlassSolidNavBar()
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
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 420, maxWidth: 520)
    #endif
    .background(theme.colors.background)
    .presentationBackground(theme.colors.background)
  }
}

extension UserProfileDeleteAccountConfirmationView {
  private func deleteAccount() async {
    guard let user else { return }

    do {
      let deletedUserID = user.id
      try await user.delete()
      forgetTrustedDeviceLocalCredentials(deletedUserID: deletedUserID)
      let shouldPresentAccountSwitcher = clerk.auth.sessions.count > 1
      let shouldDismissUserProfile = clerk.user == nil && !shouldPresentAccountSwitcher
      dismiss()
      builtInRouter.dismiss(shouldDismissUserProfile ? .exitUserProfile : .popToRoot)
      if shouldPresentAccountSwitcher {
        navigation.accountSwitcherIsPresented = true
      }
    } catch {
      self.error = error
      ClerkLogger.error("Failed to delete account", error: error)
    }
  }

  private func forgetTrustedDeviceLocalCredentials(deletedUserID: String) {
    do {
      try clerk.trustedDevices.forgetLocalCredentials(deletedUserID: deletedUserID)
    } catch {
      ClerkLogger.error(
        "Failed to delete trusted-device local credentials after account deletion. This is non-critical.",
        error: error
      )
    }
  }
}

#Preview {
  UserProfileDeleteAccountConfirmationView()
    .environment(UserProfileSheetNavigation())
    .environment(
      UserProfileBuiltInRouter(
        push: { _ in },
        dismissAction: { _ in }
      )
    )
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
    .environment(\.locale, .init(identifier: "es"))
}

#endif
