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

          // Error message
          if let errorMessage {
            Text(errorMessage)
              .font(.system(size: 14))
              .foregroundStyle(.red)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }

          // Divider
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

          // Alternative login methods
          VStack(spacing: 16) {
            // Toggle between email and phone
            SocialButton(
              icon: loginMode == .phone ? "envelope" : "iphone",
              title: loginMode == .phone ? "Continue with email" : "Continue with Phone",
              action: {
                dismissKeyboard()
                withAnimation {
                  loginMode = loginMode == .phone ? .email : .phone
                  errorMessage = nil
                }
              }
            )

            // Apple Sign In
            SocialButton(
              provider: .apple,
              isLoading: isSocialLoading && loadingSocialProvider == .apple,
              title: "Continue with Apple",
              action: signInWithApple
            )

            // Google Sign In
            SocialButton(
              provider: .google,
              isLoading: isSocialLoading && loadingSocialProvider == .google,
              title: "Continue with Google",
              action: { signInWithOAuth(.google) }
            )

            // Facebook Sign In
            SocialButton(
              provider: .facebook,
              isLoading: isSocialLoading && loadingSocialProvider == .facebook,
              title: "Continue with Facebook",
              action: { signInWithOAuth(.facebook) }
            )
          }
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
          Button {
            dismissKeyboard()
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(Color(uiColor: .label))
          }
          .buttonStyle(.plain)
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

#Preview {
  LoginView()
    .environment(Clerk.preview { preview in
      preview.isSignedIn = false
    })
}
