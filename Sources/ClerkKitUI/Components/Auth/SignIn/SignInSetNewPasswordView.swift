//
//  SignInSetNewPasswordView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SignInSetNewPasswordView: View {
  let mode: Mode

  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation
  @Environment(AuthState.self) private var authState

  @State private var identifier = ""
  @State private var signOutOfOtherDevices = false
  @State private var fieldError: Error?
  @FocusState private var focusedField: Field?

  var signIn: SignIn? {
    clerk.auth.currentSignIn
  }

  var resetButtonIsDisabled: Bool {
    authState.signInNewPassword.isEmptyTrimmed || authState.signInConfirmNewPassword.isEmptyTrimmed || authState.signInNewPassword != authState.signInConfirmNewPassword
  }

  enum Field {
    case new, confirm
  }

  enum Mode {
    case signIn
    case sessionTask
  }

  init(mode: Mode = .signIn) {
    self.mode = mode
  }

  var body: some View {
    @Bindable var authState = authState

    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Set new password")

          if mode == .sessionTask {
            WarningText("Your account requires a new password before you can continue", bundle: .module)
          }
        }
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

            // Keep a local copy because sign-in identifier can be cleared after reset completion.
            identifier = initialIdentifier
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
  var initialIdentifier: String {
    switch mode {
    case .signIn:
      signIn?.identifier ?? ""
    case .sessionTask:
      clerk.user?.usernameForPasswordKeeper ?? ""
    }
  }

  func setNewPassword() async {
    fieldError = nil
    focusedField = nil

    do {
      guard authState.signInNewPassword == authState.signInConfirmNewPassword else {
        throw ClerkClientError(message: "Passwords don't match.")
      }

      switch mode {
      case .signIn:
        try await resetPasswordFromSignIn()
      case .sessionTask:
        try await resetPasswordFromSessionTask()
      }
    } catch {
      fieldError = error
    }
  }

  private func resetPasswordFromSignIn() async throws {
    guard var signIn else {
      navigation.path = []
      return
    }

    signIn = try await signIn.resetPassword(
      newPassword: authState.signInNewPassword,
      signOutOfOtherSessions: signOutOfOtherDevices
    )

    navigation.setToStepForStatus(signIn: signIn)
  }

  private func resetPasswordFromSessionTask() async throws {
    guard let user = clerk.user else {
      navigation.path = []
      return
    }

    try await user.updatePassword(
      .init(
        currentPassword: nil,
        newPassword: authState.signInNewPassword,
        signOutOfOtherSessions: signOutOfOtherDevices
      )
    )

    navigation.handleSessionTaskCompletion(session: clerk.session)
  }
}

#Preview {
  SignInSetNewPasswordView()
    .environment(\.clerkTheme, .clerk)
}

#endif
