//
//  SessionTaskResetPasswordView.swift
//  Clerk
//
//  Created by Clerk on 1/28/26.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SessionTaskResetPasswordView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var newPassword = ""
  @State private var confirmPassword = ""
  @State private var signOutOfOtherDevices = true
  @State private var fieldError: Error?
  @FocusState private var focusedField: Field?

  var session: Session? {
    // Find the first pending session with tasks (might not be the active session)
    clerk.client?.sessions.first { $0.status == .pending && $0.currentTask != nil }
  }

  var user: User? {
    // Get the user from the pending session, not from clerk.user (which uses the active session)
    session?.user
  }

  var resetButtonIsDisabled: Bool {
    newPassword.isEmptyTrimmed || confirmPassword.isEmptyTrimmed || newPassword != confirmPassword
  }

  enum Field {
    case new, confirm
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        HeaderView(style: .title, text: "Reset your password")
          .padding(.bottom, 8)

        HeaderView(style: .subtitle, text: "Your password must be reset before you can continue")
          .padding(.bottom, 32)

        VStack(spacing: 24) {
          ClerkTextField(
            "New password",
            text: $newPassword,
            isSecure: true,
            fieldState: fieldError != nil ? .error : .default
          )
          .textContentType(.newPassword)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($focusedField, equals: .new)
          .onFirstAppear {
            focusedField = .new
          }

          VStack(spacing: 8) {
            ClerkTextField(
              "Confirm password",
              text: $confirmPassword,
              isSecure: true,
              fieldState: fieldError != nil ? .error : .default
            )
            .textContentType(.newPassword)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .confirm)

            if let fieldError {
              ErrorText(error: fieldError, alignment: .leading)
                .font(theme.fonts.subheadline)
                .transition(.blurReplace.animation(.default.speed(2)))
                .id(fieldError.localizedDescription)
            }
          }

          Toggle("Sign out of all other devices", isOn: $signOutOfOtherDevices)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.foreground)
            .tint(theme.colors.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.colors.muted)
            .clipShape(.rect(cornerRadius: theme.design.borderRadius))

          AsyncButton {
            await resetPassword()
          } label: { isRunning in
            HStack(spacing: 4) {
              Text("Reset password", bundle: .module)
            }
            .frame(maxWidth: .infinity)
            .overlayProgressView(isActive: isRunning) {
              SpinnerView(color: theme.colors.primaryForeground)
            }
          }
          .buttonStyle(.primary())
          .disabled(resetButtonIsDisabled)
          .simultaneousGesture(TapGesture())
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .sensoryFeedback(.error, trigger: fieldError?.localizedDescription) {
      $1 != nil
    }
    .navigationBarBackButtonHidden()
  }
}

extension SessionTaskResetPasswordView {
  func resetPassword() async {
    fieldError = nil
    focusedField = nil

    do {
      guard newPassword == confirmPassword else {
        throw ClerkClientError(message: "Passwords don't match.")
      }

      guard let user else {
        throw ClerkClientError(message: "User not found.")
      }

      _ = try await user.updatePassword(
        User.UpdatePasswordParams(
          currentPassword: nil,
          newPassword: newPassword,
          signOutOfOtherSessions: signOutOfOtherDevices
        )
      )

      // Refresh the client to get the updated session
      // The view will automatically update when the session changes
      _ = try? await clerk.refreshClient()
    } catch {
      fieldError = error
    }
  }
}

#Preview {
  SessionTaskResetPasswordView()
    .environment(\.clerkTheme, .clerk)
}

#endif
