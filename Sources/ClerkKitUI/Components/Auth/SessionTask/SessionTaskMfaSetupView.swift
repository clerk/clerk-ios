//
//  SessionTaskMfaSetupView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

/// A full-screen MFA enrollment flow shown when a session requires forced MFA setup.
///
/// This view is presented after sign-in/sign-up completes when the backend requires
/// the user to enroll in at least one MFA method before the session can become active.
struct SessionTaskMfaSetupView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var error: Error?

  let token: AuthFlowPresentationToken

  private var environment: Clerk.Environment? {
    clerk.environment
  }

  private var user: User? {
    clerk.user
  }

  private var phoneCodeIsEnabled: Bool {
    environment?.mfaPhoneCodeIsEnabled == true
  }

  private var authenticatorAppIsEnabled: Bool {
    environment?.mfaAuthenticatorAppIsEnabled == true && user?.totpEnabled != true
  }

  private var noMethodsAvailable: Bool {
    !phoneCodeIsEnabled && !authenticatorAppIsEnabled
  }

  var body: some View {
    if noMethodsAvailable {
      GetHelpView(context: .sessionTask(.generic))
        .navigationBarBackButtonHidden()
    } else {
      chooseMethodView
        .navigationBarBackButtonHidden()
    }
  }

  private var chooseMethodView: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Set up two-step verification")
          HeaderView(style: .subtitle, text: "Choose which method you prefer to protect your account with an extra layer of security")
        }
        .padding(.bottom, 32)

        VStack(spacing: 16) {
          if phoneCodeIsEnabled {
            Button {
              guard clerk.authFlowPresentationIsCurrent(token) else { return }
              navigation.appendPostAuthDestination(.taskMfaSmsChooseNumber(token: token))
            } label: {
              StrategyOptionButton(iconName: "icon-phone", text: "SMS code")
            }
            .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.SessionTask.SetupMfa.smsCode)
            .buttonStyle(.secondary())
          }

          if authenticatorAppIsEnabled {
            AsyncButton {
              await createTotp()
            } label: { isRunning in
              StrategyOptionButton(iconName: "icon-key", text: "Authenticator application")
                .overlayProgressView(isActive: isRunning)
            }
            .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.SessionTask.SetupMfa.authenticatorApp)
            .buttonStyle(.secondary())
          }
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .preGlassSolidNavBar()
    .toolbar {
      UserButtonToolbarItem(presentationContext: .sessionTaskToolbar)
    }
    .clerkErrorPresenting($error)
  }

  private func createTotp() async {
    guard clerk.authFlowPresentationIsCurrent(token),
          let user
    else {
      return
    }

    do {
      let totp = try await user.createTOTP()
      guard clerk.authFlowPresentationIsCurrent(token) else { return }
      navigation.appendPostAuthDestination(.taskMfaTotp(
        totpResource: totp,
        token: token
      ))
    } catch {
      self.error = error
      ClerkLogger.error("Failed to create TOTP", error: error)
    }
  }
}

#endif
