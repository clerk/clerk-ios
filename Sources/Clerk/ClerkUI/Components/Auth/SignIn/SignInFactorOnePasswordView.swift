//
//  SignInFactorOnePasswordView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/17/25.
//

import SwiftUI

struct SignInFactorOnePasswordView: View {
  @Environment(\.clerk) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.authState) private var authState
  @FocusState private var isFocused: Bool
  
  var signIn: SignIn? {
    clerk.client?.signIn
  }

  var body: some View {
    @Bindable var authState = authState

    ScrollView {
      VStack(spacing: 0) {
        AppLogoView()
          .frame(maxHeight: 44)
          .padding(.bottom, 24)
        
        VStack(spacing: 8) {
          Text("Enter password", bundle: .module)
            .font(theme.fonts.title)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
            .frame(minHeight: 28)
            .foregroundStyle(theme.colors.text)

          Text("Enter the password for your account", bundle: .module)
            .font(theme.fonts.subheadline)
            .multilineTextAlignment(.center)
            .frame(minHeight: 18)
            .foregroundStyle(theme.colors.textSecondary)
          
          if let identifier = signIn?.identifier {
            Button(action: {
              authState.step = .signInStart
            }, label: {
              IdentityPreviewView(label: identifier)
            })
            .buttonStyle(.secondary(config: .init(size: .small)))
          }
        }
        .padding(.bottom, 32)
        
        VStack(spacing: 24) {
          
          ClerkTextField(
            "Enter your password",
            text: $authState.password,
            isSecure: true
          )
          .textContentType(.password)
          .textInputAutocapitalization(.never)
          .focused($isFocused)
          .onFirstAppear {
            isFocused = true
          }

          AsyncButton(
            action: {
              // sign in with password
            },
            label: { isRunning in
              HStack(spacing: 4) {
                Text("Continue", bundle: .module)
                Image("triangle-right", bundle: .module)
                  .foregroundStyle(theme.colors.textOnPrimaryBackground)
                  .opacity(0.6)
              }
              .frame(maxWidth: .infinity)
              .overlayProgressView(isActive: isRunning) {
                SpinnerView(color: theme.colors.textOnPrimaryBackground)
              }
            }
          )
          .buttonStyle(.primary())
          .disabled(authState.password.isEmpty)
        }
        .padding(.bottom, 16)
        
        Button {
          authState.step = .signInStart
        } label: {
          Text("Use another method", bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.primary)
            .frame(minHeight: 20)
        }
        .buttonStyle(
          .primary(
            config: .init(
              emphasis: .none,
              size: .small
            )
          )
        )
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 32)
    }
    .background(theme.colors.background)
    .scrollBounceBehavior(.basedOnSize)
  }
}

#Preview {
  SignInFactorOnePasswordView()
    .environment(\.clerk, .mock)
}

#Preview("Spanish") {
  SignInFactorOnePasswordView()
    .environment(\.clerk, .mock)
    .environment(\.locale, .init(identifier: "es"))
}
