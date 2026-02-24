//
//  SignInFactorTwoBackupCodeView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SignInFactorTwoBackupCodeView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation
  @Environment(AuthState.self) private var authState

  @FocusState private var isFocused: Bool
  @State private var fieldError: Error?

  var signIn: SignIn? {
    clerk.auth.currentSignIn
  }

  let factor: Factor

  var body: some View {
    @Bindable var authState = authState

    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Enter a backup code")
          HeaderView(style: .subtitle, text: "Your backup code is the one you got when setting up two-step authentication.")
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          VStack(spacing: 8) {
            ClerkTextField(
              "Backup code",
              text: $authState.signInBackupCode,
              fieldState: fieldError != nil ? .error : .default
            )
            .textInputAutocapitalization(.never)
            .focused($isFocused)
            .onFirstAppear {
              isFocused = true
            }

            if let fieldError {
              ErrorText(error: fieldError, alignment: .leading)
                .font(theme.fonts.subheadline)
                .transition(.blurReplace.animation(.default.speed(2)))
                .id(fieldError.localizedDescription)
            }
          }

          AsyncButton {
            await submit()
          } label: { isRunning in
            ContinueButtonLabelView(isActive: isRunning)
          }
          .buttonStyle(.primary())
          .disabled(authState.signInBackupCode.isEmpty)
          .simultaneousGesture(TapGesture())
        }
        .padding(.bottom, 16)

        Button {
          navigation.path.append(
            AuthView.Destination.signInFactorTwoUseAnotherMethod(
              currentFactor: factor
            )
          )
        } label: {
          Text("Use another method", bundle: .module)
            .frame(maxWidth: .infinity)
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
  }
}

extension SignInFactorTwoBackupCodeView {
  func submit() async {
    isFocused = false

    do {
      guard var signIn else {
        navigation.path = []
        return
      }

      signIn = try await signIn.verifyMfaCode(authState.signInBackupCode, type: .backupCode)

      fieldError = nil
      navigation.setToStepForStatus(signIn: signIn)
    } catch {
      fieldError = error
    }
  }
}

#Preview {
  SignInFactorTwoBackupCodeView(factor: .mockBackupCode)
    .environment(\.clerkTheme, .clerk)
}

#endif
