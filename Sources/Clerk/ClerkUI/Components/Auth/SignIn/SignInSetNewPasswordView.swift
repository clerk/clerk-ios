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

    @FocusState private var focusedField: Field?
    @State private var fieldError: Error?
    @State private var error: Error?

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
            .focused($focusedField, equals: .new)
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
              .focused($focusedField, equals: .confirm)

              if let fieldError {
                ErrorText(error: fieldError, alignment: .leading)
                  .font(theme.fonts.subheadline)
                  .transition(.blurReplace.animation(.default.speed(2)))
                  .id(fieldError.localizedDescription)
              }
            }

            AsyncButton {
              // reset password
            } label: { isRunning in
              HStack(spacing: 4) {
                Text("Reset password", bundle: .module)
                Image("icon-triangle-right", bundle: .module)
                  .foregroundStyle(theme.colors.textOnPrimaryBackground)
                  .opacity(0.6)
              }
              .frame(maxWidth: .infinity)
              .overlayProgressView(isActive: isRunning) {
                SpinnerView(color: theme.colors.textOnPrimaryBackground)
              }
            }
            .buttonStyle(.primary())
            .disabled(authState.password.isEmpty)
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

  #Preview {
    SignInSetNewPasswordView()
      .environment(\.clerkTheme, .clerk)
  }

#endif
