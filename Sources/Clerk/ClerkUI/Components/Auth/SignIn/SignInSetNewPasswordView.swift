//
//  SignInResetPasswordView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/7/25.
//

#if os(iOS)

  import SwiftUI

  struct SignInSetNewPasswordView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.authState) private var authState

    @State private var signOutOfOtherDevices = false
    @State private var fieldError: Error?
    @FocusState private var focusedField: Field?

    var signIn: SignIn? {
      clerk.client?.signIn
    }

    var resetButtonIsDisabled: Bool {
      if authState.newPassword.isEmpty || authState.confirmNewPassword.isEmpty {
        return true
      }

      return false
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
              text: $authState.newPassword,
              isSecure: true,
              fieldState: fieldError != nil ? .error : .default
            )
            .textContentType(.newPassword)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .new)
            .hiddenTextField(text: .constant(signIn?.identifier ?? ""), textContentType: .username)
            .onFirstAppear {
              focusedField = .new
            }

            VStack(spacing: 8) {
              ClerkTextField(
                "Confirm password",
                text: $authState.confirmNewPassword,
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
              .foregroundStyle(theme.colors.text)
              .tint(theme.colors.primary)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(theme.colors.backgroundSecondary)
              .clipShape(.rect(cornerRadius: theme.design.borderRadius))

            AsyncButton {
              await setNewPassword()
            } label: { isRunning in
              HStack(spacing: 4) {
                Text("Reset password", bundle: .module)
              }
              .frame(maxWidth: .infinity)
              .overlayProgressView(isActive: isRunning) {
                SpinnerView(color: theme.colors.textOnPrimaryBackground)
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
        guard authState.newPassword == authState.confirmNewPassword else {
          throw ClerkClientError(message: "Passwords don't match.")
        }

        guard var signIn else {
          authState.path = NavigationPath()
          return
        }

        signIn = try await signIn.resetPassword(
          .init(
            password: authState.newPassword,
            signOutOfOtherSessions: signOutOfOtherDevices
          ))
        
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
