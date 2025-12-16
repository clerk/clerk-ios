//
//  LoginView.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import AuthenticationServices
import ClerkKit
import SwiftUI

enum LoginMode {
  case phone
  case email
}

struct LoginView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(Clerk.self) private var clerk

  @State private var loginMode: LoginMode = .phone
  @State private var showVerification = false
  @State private var pendingVerification: PendingVerification?
  @State private var isFormLoading = false
  @State private var isSocialLoading = false
  @State private var loadingSocialProvider: OAuthProvider?
  @State private var errorMessage: String?

  private var isBusy: Bool {
    isFormLoading || isSocialLoading
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          switch loginMode {
          case .phone:
            PhoneLoginView(
              showVerification: $showVerification,
              pendingVerification: $pendingVerification,
              isLoading: $isFormLoading,
              errorMessage: $errorMessage
            )
          case .email:
            EmailLoginView(
              showVerification: $showVerification,
              pendingVerification: $pendingVerification,
              isLoading: $isFormLoading,
              errorMessage: $errorMessage
            )
          }

          LoginErrorMessage(message: errorMessage)

          LoginDivider()

          SocialLoginButtons(
            loginMode: loginMode,
            isSocialLoading: isSocialLoading,
            loadingSocialProvider: loadingSocialProvider,
            onToggleLoginMode: toggleLoginMode,
            onAppleSignIn: signInWithApple,
            onOAuthSignIn: signInWithOAuth
          )
          .disabled(isBusy)

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
    }
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
    .sheet(isPresented: $showVerification, onDismiss: { pendingVerification = nil }) {
      if let pendingVerification {
        NavigationStack {
          OTPVerificationView(pending: pendingVerification)
        }
      }
    }
  }

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
      isSocialLoading = true
      loadingSocialProvider = .apple
      defer {
        isSocialLoading = false
        loadingSocialProvider = nil
      }
      do {
        let credential = try await SignInWithAppleHelper.getAppleIdCredential(
          requestedScopes: [.email, .fullName]
        )

        guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
          errorMessage = "Unable to retrieve the Apple identity token."
          return
        }

        try await clerk.auth.signUpWithIdToken(
          idToken,
          provider: .apple,
          firstName: credential.fullName?.givenName,
          lastName: credential.fullName?.familyName
        )
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
      isSocialLoading = true
      loadingSocialProvider = provider
      defer {
        isSocialLoading = false
        loadingSocialProvider = nil
      }
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

// MARK: - LoginErrorMessage

private struct LoginErrorMessage: View {
  let message: String?

  var body: some View {
    if let message {
      Text(message)
        .font(.system(size: 14))
        .foregroundStyle(.red)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
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
  let loginMode: LoginMode
  let isSocialLoading: Bool
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
        isLoading: isSocialLoading && loadingSocialProvider == .apple,
        title: "Continue with Apple",
        action: onAppleSignIn
      )

      AuthOptionButton(
        provider: .google,
        isLoading: isSocialLoading && loadingSocialProvider == .google,
        title: "Continue with Google",
        action: { onOAuthSignIn(.google) }
      )

      AuthOptionButton(
        provider: .facebook,
        isLoading: isSocialLoading && loadingSocialProvider == .facebook,
        title: "Continue with Facebook",
        action: { onOAuthSignIn(.facebook) }
      )
    }
  }
}

// MARK: - CloseButton

private struct CloseButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color(uiColor: .label))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Preview

#Preview {
  LoginView()
    .environment(Clerk.preview { preview in
      preview.isSignedIn = false
    })
}
