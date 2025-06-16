//
//  UserProfileChangePasswordView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/16/25.
//

#if os(iOS)

  import SwiftUI

  struct UserProfileChangePasswordView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var signOutOfOtherSessions = false
    @State private var error: Error?

    @FocusState private var focusedField: Field?

    enum Field {
      case newPassword, confirmNewPassword
    }

    var user: User? { clerk.user }

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(spacing: 24) {
            Group {
              ClerkTextField("New password", text: $newPassword, isSecure: true)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .newPassword)
                .hiddenTextField(text: .constant(""), textContentType: .username)
              ClerkTextField("Confirm password", text: $confirmNewPassword, isSecure: true)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirmNewPassword)
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            signOutOfOtherDevicesView

            AsyncButton {
              await resetPassword()
            } label: { isRunning in
              Text("Save")
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
        .clerkErrorPresenting($error)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              dismiss()
            }
            .foregroundStyle(theme.colors.primary)
          }

          ToolbarItem(placement: .principal) {
            Text("Update password", bundle: .module)
              .font(theme.fonts.headline)
              .foregroundStyle(theme.colors.text)
          }
        }
        .onFirstAppear {
          focusedField = .newPassword
        }
      }
    }

    @ViewBuilder
    var signOutOfOtherDevicesView: some View {
      VStack(spacing: 8) {
        Toggle("Sign out of all other devices", isOn: $signOutOfOtherSessions)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.text)
          .tint(theme.colors.primary)
          .frame(minHeight: 22)
        
        Text("It is recommended to sign out of all other devices which may have used your old password.", bundle: .module)
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(theme.colors.backgroundSecondary, in: .rect(cornerRadius: theme.design.borderRadius))
    }
  }

  extension UserProfileChangePasswordView {

    func resetPassword() async {
      guard let user else { return }

      do {
        try await user.updatePassword(
          .init(
            newPassword: newPassword,
            signOutOfOtherSessions: signOutOfOtherSessions
          )
        )
        
        dismiss()
      } catch {
        self.error = error
      }
    }

  }

  #Preview {
    UserProfileChangePasswordView()
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
