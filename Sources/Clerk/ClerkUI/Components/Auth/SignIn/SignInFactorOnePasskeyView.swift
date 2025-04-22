//
//  SignInFactorOnePasskeyView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/22/25.
//

import SwiftUI

struct SignInFactorOnePasskeyView: View {
  @Environment(\.clerk) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.authState) private var authState
  @State var error: Error?

  var signIn: SignIn? {
    clerk.client?.signIn
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        AppLogoView()
          .frame(maxHeight: 44)
          .padding(.bottom, 24)

        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Use your passkey")
          HeaderView(style: .subtitle, text: "Using your passkey confirms it's you. Your device may ask for your fingerprint, face or screen lock.")

          if let identifier = signIn?.identifier {
            Button {
              authState.step = .signInStart
            } label: {
              IdentityPreviewView(label: identifier)
            }
            .buttonStyle(.secondary(config: .init(size: .small)))
          }
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          Image(systemName: "person.badge.key.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 56, height: 56)
            .foregroundStyle(theme.colors.textSecondary)
          
          AsyncButton {
            await authWithPasskey()
          } label: { isRunning in
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
          .buttonStyle(.primary())
          
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
        }
        .padding(.bottom, 32)
        
        SecuredByClerkView()
      }
      .padding(.vertical, 32)
      .padding(.horizontal, 16)
    }
    .taskOnce {
      try? await Task.sleep(for: .seconds(0.5))
      await authWithPasskey()
    }
  }
}

extension SignInFactorOnePasskeyView {
  
  func authWithPasskey() async {
    guard let signIn else {
      authState.step = .signInStart
      return
    }
    
    do {
      let signIn = try await signIn.prepareFirstFactor(strategy: .passkey)
      let credential = try await signIn.getCredentialForPasskey()
      try await signIn.attemptFirstFactor(
        strategy: .passkey(publicKeyCredential: credential)
      )
    } catch {
      self.error = error
      dump(error)
    }
  }
  
}

#Preview {
  SignInFactorOnePasskeyView()
    .environment(\.clerk, .mock)
}

#Preview("Localized") {
  SignInFactorOnePasskeyView()
    .environment(\.clerk, .mock)
    .environment(\.locale, .init(identifier: "fr"))
}
