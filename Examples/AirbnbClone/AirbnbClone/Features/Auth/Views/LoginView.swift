//
//  LoginView.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import AuthenticationServices
import ClerkKit
import SwiftUI

extension EnvironmentValues {
  @Entry var otpLoginMode: Binding<LoginMode?> = .constant(nil)
}

struct LoginView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(Clerk.self) private var clerk
  @Environment(Router.self) private var router

  @State private var loginMode: LoginMode.Method = .phone
  @State private var loadingSocialProvider: OAuthProvider?
  @State private var errorMessage: String?
  @State private var otpLoginMode: LoginMode?

  var body: some View {
    @Bindable var router = router

    NavigationStack(path: $router.authPath) {
      ScrollView {
        VStack(spacing: 24) {
          switch loginMode {
          case .phone:
            PhoneLoginView()
          case .email:
            EmailLoginView()
          }

          LoginDivider()

          SocialLoginButtons(
            loginMode: loginMode,
            loadingSocialProvider: loadingSocialProvider,
            onToggleLoginMode: toggleLoginMode,
            onAppleSignIn: signInWithApple,
            onOAuthSignIn: signInWithOAuth
          )
          .disabled(loadingSocialProvider != nil)

          Spacer(minLength: 40)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
      }
      .navigationTitle("Log in or sign up")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          CloseButton {
            dismissKeyboard()
            dismiss()
          }
        }
        .sharedBackgroundVisibility(.hidden)
      }
      .navigationDestination(for: AuthDestination.self) { destination in
        switch destination {
        case .finishSigningUp(let identifierValue, let loginMode):
          FinishSigningUpView(
            identifierValue: identifierValue,
            loginMode: loginMode
          )
        }
      }
    }
    .tint(Color(.label))
    .task {
      for await event in clerk.auth.events {
        switch event {
        case .signInCompleted, .signUpCompleted:
          dismiss()
          return
        default:
          break
        }
      }
    }
    .sheet(isPresented: $router.showOTPVerification, onDismiss: {
      otpLoginMode = nil
    }) {
      if let loginMode = otpLoginMode {
        NavigationStack {
          OTPVerificationView(loginMode: loginMode)
        }
        .tint(Color(uiColor: .label))
      }
    }
    .environment(\.otpLoginMode, $otpLoginMode)
  }
}

// MARK: - Actions

extension LoginView {
  private func toggleLoginMode() {
    dismissKeyboard()
    withAnimation {
      loginMode = loginMode == .phone ? .email : .phone
      errorMessage = nil
    }
  }

  private func signInWithApple() {
    Task {
      dismissKeyboard()
      errorMessage = nil
      loadingSocialProvider = .apple
      defer { loadingSocialProvider = nil }
      do {
        try await clerk.auth.signInWithApple()
        dismiss()
      } catch {
        if !error.isUserCancellation {
          errorMessage = error.localizedDescription
        }
      }
    }
  }

  private func signInWithOAuth(_ provider: OAuthProvider) {
    Task {
      dismissKeyboard()
      errorMessage = nil
      loadingSocialProvider = provider
      defer { loadingSocialProvider = nil }
      do {
        try await clerk.auth.signUpWithOAuth(provider: provider)
        dismiss()
      } catch {
        if !error.isUserCancellation {
          errorMessage = error.localizedDescription
        }
      }
    }
  }
}

// MARK: - LoginDivider

private struct LoginDivider: View {
  var body: some View {
    HStack {
      Rectangle()
        .fill(Color(.systemGray4))
        .frame(height: 1)
      Text("or")
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
      Rectangle()
        .fill(Color(.systemGray4))
        .frame(height: 1)
    }
    .padding(.vertical, 8)
  }
}

// MARK: - SocialLoginButtons

private struct SocialLoginButtons: View {
  let loginMode: LoginMode.Method
  let loadingSocialProvider: OAuthProvider?
  let onToggleLoginMode: () -> Void
  let onAppleSignIn: () -> Void
  let onOAuthSignIn: (OAuthProvider) -> Void

  var body: some View {
    VStack(spacing: 16) {
      AuthOptionButton(
        icon: loginMode == .phone ? "envelope" : "iphone",
        title: loginMode == .phone ? "Continue with email" : "Continue with phone",
        action: onToggleLoginMode
      )

      AuthOptionButton(
        provider: .apple,
        isLoading: loadingSocialProvider == .apple,
        title: "Continue with Apple",
        action: onAppleSignIn
      )

      AuthOptionButton(
        provider: .google,
        isLoading: loadingSocialProvider == .google,
        title: "Continue with Google",
        action: { onOAuthSignIn(.google) }
      )

      AuthOptionButton(
        provider: .facebook,
        isLoading: loadingSocialProvider == .facebook,
        title: "Continue with Facebook",
        action: { onOAuthSignIn(.facebook) }
      )
    }
  }
}

// MARK: - Preview

#Preview {
  LoginView()
    .environment(Clerk.preview { preview in
      preview.isSignedIn = false
    })
    .environment(Router())
}
