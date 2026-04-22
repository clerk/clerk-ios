//
//  SignInFactorOneEmailLinkView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI
import UIKit

struct EmailLinkVerificationView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var deliveryState = DeliveryState.idle
  @State private var error: Error?

  let mode: Mode

  private var emailAddress: String? {
    switch mode {
    case .signIn(let factor):
      factor.safeIdentifier
    case .signUp:
      clerk.auth.currentSignUp?.emailAddress
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        headerSection
        inputSection

        SecuredByClerkView()
          .padding(.top, 32)
      }
      .padding(16)
    }
    .clerkErrorPresenting($error)
    .background(theme.colors.background)
    .taskOnce {
      await sendInitialLinkIfNeeded()
    }
  }
}

// MARK: - Types

extension EmailLinkVerificationView {
  enum Mode {
    case signIn(Factor)
    case signUp
  }

  enum DeliveryState {
    case idle
    case sending
    case sent
    case failed(Error)
  }
}

// MARK: - Subviews

extension EmailLinkVerificationView {
  private var headerSection: some View {
    VStack(spacing: 8) {
      HeaderView(style: .title, text: "Check your email")
      HeaderView(style: .subtitle, text: subtitleString)

      if let emailAddress {
        Button {
          navigation.path = []
        } label: {
          IdentityPreviewView(label: emailAddress)
        }
        .buttonStyle(.secondary(config: .init(size: .small)))
        .simultaneousGesture(TapGesture())
      }
    }
    .padding(.bottom, 32)
  }

  private var subtitleString: LocalizedStringKey {
    if let appName = clerk.environment?.displayConfig.applicationName {
      "to continue to \(appName)"
    } else {
      "to continue"
    }
  }

  private var inputSection: some View {
    VStack(spacing: 24) {
      openEmailAppButton

      resendSection

      if case .signIn(let factor) = mode {
        useAnotherMethodButton(factor: factor)
      }
    }
  }

  private var openEmailAppButton: some View {
    Button {
      openEmailApp()
    } label: {
      Text("Open email app", bundle: .module)
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(
      .secondary(
        config: .init(
          emphasis: .high,
          size: .large
        )
      )
    )
    .disabled(isSendingLink)
    .simultaneousGesture(TapGesture())
  }

  private var resendSection: some View {
    AsyncButton {
      await sendLink()
    } label: { isRunning in
      HStack(spacing: 2) {
        Text("Didn't receive an email?", bundle: .module)
        Text("Resend", bundle: .module)
          .foregroundStyle(theme.colors.primary)
      }
      .overlayProgressView(isActive: isRunning)
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(
      .secondary(
        config: .init(
          emphasis: .none,
          size: .small
        )
      )
    )
    .disabled(isSendingLink)
    .simultaneousGesture(TapGesture())
  }

  private func useAnotherMethodButton(factor: Factor) -> some View {
    Button {
      navigation.path.append(
        AuthView.Destination.signInFactorOneUseAnotherMethod(
          currentFactor: factor
        )
      )
    } label: {
      Text("Use another method", bundle: .module)
    }
    .buttonStyle(
      .primary(
        config: .init(
          emphasis: .none,
          size: .small
        )
      )
    )
    .simultaneousGesture(TapGesture())
  }
}

// MARK: - Helpers

extension EmailLinkVerificationView {
  private var isSendingLink: Bool {
    if case .sending = deliveryState {
      true
    } else {
      false
    }
  }
}

// MARK: - Actions

extension EmailLinkVerificationView {
  @MainActor
  private func sendInitialLinkIfNeeded() async {
    let alreadySent: Bool = switch mode {
    case .signIn:
      clerk.auth.currentSignIn?.firstFactorVerification?.strategy == .emailLink
        && clerk.auth.currentSignIn?.firstFactorVerification?.status == .unverified
    case .signUp:
      clerk.auth.currentSignUp?.emailVerification?.strategy == .emailLink
        && clerk.auth.currentSignUp?.emailVerification?.status == .unverified
    }

    guard !alreadySent else {
      deliveryState = .sent
      return
    }

    await sendLink()
  }

  @MainActor
  private func sendLink() async {
    deliveryState = .sending

    do {
      switch mode {
      case .signIn(let factor):
        guard let signIn = clerk.auth.currentSignIn else {
          deliveryState = .idle
          navigation.path = []
          return
        }
        try await signIn.sendEmailLink(emailAddressId: factor.emailAddressId)

      case .signUp:
        guard let signUp = clerk.auth.currentSignUp else {
          deliveryState = .idle
          navigation.path = []
          return
        }
        try await signUp.sendEmailLink()
      }
      deliveryState = .sent
    } catch {
      deliveryState = .failed(error)
      self.error = error
      ClerkLogger.error("Failed to send email link", error: error)
    }
  }

  @MainActor
  private func openEmailApp() {
    guard let url = URL(string: "mailto:") else {
      error = ClerkClientError(message: "No email app is available on this device.")
      return
    }

    UIApplication.shared.open(url, options: [:]) { success in
      if !success {
        Task { @MainActor in
          error = ClerkClientError(message: "No email app is available on this device.")
        }
      }
    }
  }
}

#Preview("Sign In") {
  EmailLinkVerificationView(
    mode: .signIn(
      Factor(
        strategy: .emailLink,
        emailAddressId: "ema_123",
        safeIdentifier: "sam@clerk.dev"
      )
    )
  )
  .clerkPreview()
}

#Preview("Sign Up") {
  EmailLinkVerificationView(mode: .signUp)
    .clerkPreview()
}

#endif
