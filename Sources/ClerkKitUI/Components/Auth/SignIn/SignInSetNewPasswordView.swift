//
//  SignInSetNewPasswordView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/7/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SignInSetNewPasswordView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthState.self) private var authState

  @State private var identifier = ""
  @State private var signOutOfOtherDevices = false
  @State private var fieldError: Error?
  @FocusState private var focusedField: Field?

  var signIn: SignIn? {
    clerk.client?.signIn
  }

  var resetButtonIsDisabled: Bool {
    authState.signInNewPassword.isEmptyTrimmed || authState.signInConfirmNewPassword.isEmptyTrimmed || authState.signInNewPassword != authState.signInConfirmNewPassword
  }

  enum Field {
    case new, confirm
  }

  var body: some View {
    @Bindable var authState = authState

    ScrollView {
      VStack(spacing: 0) {
        HeaderView(style: .title, text: "Set new password")
          .padding(.bottom, 32)

        VStack(spacing: 24) {
          ClerkTextField(
            "New password",
            text: $authState.signInNewPassword,
            isSecure: true,
            fieldState: fieldError != nil ? .error : .default
          )
          .textContentType(.newPassword)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($focusedField, equals: .new)
          .hiddenTextField(text: $identifier, textContentType: .username)
          .onFirstAppear {
            focusedField = .new

            // we need to create a local copy of this to keep around because
            // once the reset flow is complete the sign in identifier gets cleared out
            identifier = signIn?.identifier ?? ""
          }

          VStack(spacing: 8) {
            ClerkTextField(
              "Confirm password",
              text: $authState.signInConfirmNewPassword,
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
            await setNewPassword()
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

extension SignInSetNewPasswordView {
  func setNewPassword() async {
    fieldError = nil
    focusedField = nil

    do {
      guard authState.signInNewPassword == authState.signInConfirmNewPassword else {
        throw ClerkClientError(message: "Passwords don't match.")
      }

      guard var signIn else {
        authState.path = []
        return
      }

      signIn = try await signIn.resetPassword(
        .init(
          password: authState.signInNewPassword,
          signOutOfOtherSessions: signOutOfOtherDevices
        )
      )

      authState.setToStepForStatus(signIn: signIn)
    } catch {
      fieldError = error
    }
  }
}

#Preview {
  SignInSetNewPasswordView()
    .environment(\.clerkTheme, .clerk)
}

#endif
