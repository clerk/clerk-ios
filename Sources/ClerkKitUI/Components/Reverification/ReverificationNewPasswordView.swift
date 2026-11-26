//
//  ReverificationNewPasswordView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct ReverificationNewPasswordView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(ReverificationFlow.self) private var flow

  let resetFactor: Factor
  let reason: ReverificationFlow.PasswordResetReason

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
          switch reason {
          case .pwned:
            WarningText("Your password was found in a data breach. Set a new password to continue.", bundle: .module)
          case .compromised:
            WarningText("Your password can't be used anymore. Set a new password to continue.", bundle: .module)
          }
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          VStack(spacing: 8) {
          ClerkTextField(
            "New password",
            text: $flow.newPassword,
            isSecure: true,
            fieldState: flow.newPasswordError != nil ? .error : .default,
            accessibilityIdentifier: ClerkAccessibilityIdentifiers.Reverification.newPassword
          )
          .textContentType(ClerkE2EEnvironment.isEnabled ? nil : .newPassword)
          .hiddenTextField(text: .constant(clerk.user?.usernameForPasswordKeeper ?? ""), textContentType: .username)
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

            if let newPasswordError = flow.newPasswordError {
              ErrorText(error: newPasswordError, alignment: .leading)
                .font(theme.fonts.subheadline)
                .transition(.blurReplace.animation(.default.speed(2)))
                .id(newPasswordError.localizedDescription)
            }
          }

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
    .onChange(of: flow.newPassword) {
      flow.newPasswordError = nil
    }
  }
}

#Preview {
  ReverificationNewPasswordView(resetFactor: .mockResetPasswordEmailCode, reason: .pwned)
    .environment(ReverificationFlow(level: .firstFactor))
    .clerkPreview()
}

#endif
