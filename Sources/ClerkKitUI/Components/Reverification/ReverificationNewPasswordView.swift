//
//  ReverificationNewPasswordView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

/// Collects the new password for a breached password. The reset code screen that follows sends it.
struct ReverificationNewPasswordView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(ReverificationFlow.self) private var flow

  let resetFactor: Factor

  @FocusState private var focusedField: Field?

  enum Field {
    case new, confirm
  }

  private var continueIsDisabled: Bool {
    flow.newPassword.isEmptyTrimmed || flow.newPassword != flow.confirmNewPassword
  }

  var body: some View {
    @Bindable var flow = flow

    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Set new password")
          WarningText("Your password was found in a data breach. Set a new password to continue.", bundle: .module)
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          ClerkTextField(
            "New password",
            text: $flow.newPassword,
            isSecure: true,
            accessibilityIdentifier: ClerkAccessibilityIdentifiers.Reverification.newPassword
          )
          .textContentType(ClerkE2EEnvironment.isEnabled ? nil : .newPassword)
          #if os(iOS)
          .textInputAutocapitalization(.never)
          #endif
          .autocorrectionDisabled()
          .focused($focusedField, equals: .new)
          .onFirstAppear {
            focusedField = .new
          }

          ClerkTextField(
            "Confirm password",
            text: $flow.confirmNewPassword,
            isSecure: true,
            accessibilityIdentifier: ClerkAccessibilityIdentifiers.Reverification.confirmPassword
          )
          .textContentType(ClerkE2EEnvironment.isEnabled ? nil : .newPassword)
          #if os(iOS)
          .textInputAutocapitalization(.never)
          #endif
          .autocorrectionDisabled()
          .focused($focusedField, equals: .confirm)

          Toggle(isOn: $flow.signOutOfOtherSessions) {
            Text("Sign out of all other devices", bundle: .module)
          }
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.foreground)
          .tint(theme.colors.primary)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(theme.colors.muted)
          .clipShape(.rect(cornerRadius: theme.design.borderRadius))

          Button {
            focusedField = nil
            flow.path.append(.factor(resetFactor, .firstFactor))
          } label: {
            Text("Continue", bundle: .module)
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.primary())
          .disabled(continueIsDisabled)
          .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Reverification.continueButton)
          .simultaneousGesture(TapGesture())
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
  }
}

#Preview {
  ReverificationNewPasswordView(resetFactor: .mockResetPasswordEmailCode)
    .environment(ReverificationFlow(level: .firstFactor))
    .clerkPreview()
}

#endif
