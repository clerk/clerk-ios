//
//  SessionTaskMfaView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

/// A full-screen MFA enrollment flow shown when a session requires forced MFA setup.
///
/// This view is presented after sign-in/sign-up completes when the backend requires
/// the user to enroll in at least one MFA method before the session can become active.
struct SessionTaskMfaView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var showSmsChooseNumber = false
  @State private var showSmsAddPhone = false
  @State private var showTotpSetup = false
  @State private var totpResource: TOTPResource?
  @State private var error: Error?

  enum BackupCodesMfaType {
    case phoneCode
    case authenticatorApp
  }

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

  private var hasAvailablePhoneNumbers: Bool {
    let phoneNumbers = (user?.phoneNumbersAvailableForMfa ?? [])
      .filter { $0.verification?.status == .verified }
    return !phoneNumbers.isEmpty
  }

  var body: some View {
    if noMethodsAvailable {
      GetHelpView(context: .signIn)
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
              if hasAvailablePhoneNumbers {
                showSmsChooseNumber = true
              } else {
                showSmsAddPhone = true
              }
            } label: {
              StrategyOptionButton(iconName: "icon-phone", text: "SMS code")
            }
            .buttonStyle(.secondary())
          }

          if authenticatorAppIsEnabled {
            AsyncButton {
              await createTotp()
            } label: { isRunning in
              StrategyOptionButton(iconName: "icon-key", text: "Authenticator application")
                .overlayProgressView(isActive: isRunning)
            }
            .buttonStyle(.secondary())
          }
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        UserButton(presentationContext: .sessionTaskToolbar)
      }
    }
    .clerkErrorPresenting($error)
    .navigationDestination(isPresented: $showSmsChooseNumber) {
      SessionTaskMfaSmsChooseNumberView {
        navigation.sessionTaskComplete = true
      }
    }
    .navigationDestination(isPresented: $showSmsAddPhone) {
      SessionTaskMfaAddPhoneView {
        navigation.sessionTaskComplete = true
      }
    }
    .navigationDestination(isPresented: $showTotpSetup) {
      if let totpResource {
        SessionTaskMfaTotpView(totp: totpResource) {
          navigation.sessionTaskComplete = true
        }
      }
    }
  }

  private func createTotp() async {
    guard let user else { return }

    do {
      let totp = try await user.createTOTP()
      totpResource = totp
      showTotpSetup = true
    } catch {
      self.error = error
      ClerkLogger.error("Failed to create TOTP", error: error)
    }
  }
}

#Preview("Choose Method") {
  SessionTaskMfaView()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
