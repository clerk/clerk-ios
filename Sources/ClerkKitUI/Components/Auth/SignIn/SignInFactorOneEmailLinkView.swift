//
//  SignInFactorOneEmailLinkView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkJSCore
import ClerkKit
import SwiftUI

struct EmailLinkVerificationView: View {
  @SwiftUI.Environment(ClerkJSCore.Clerk.self) private var jsClerk
  @SwiftUI.Environment(\.clerkTheme) private var theme
  @SwiftUI.Environment(AuthNavigation.self) private var navigation
  @SwiftUI.Environment(AuthState.self) private var authState
  @SwiftUI.Environment(\.authFlowRequestOwnerId) private var authFlowRequestOwnerId
  @SwiftUI.Environment(\.openURL) private var openURL

  @State private var deliveryState = DeliveryState.idle
  @State private var error: Error?

  let mode: Mode

  private var emailAddress: String? {
    switch mode {
    case .signIn(let factor):
      factor.safeIdentifier
    case .signUp:
      jsClerk.client.signUp.emailAddress
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
      await AuthFlowRequestScope.withOwner(authFlowRequestOwnerId) {
        await sendInitialLinkIfNeeded()
      }
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
        IdentityPreviewView(
          label: emailAddress,
          isEnabled: !authState.authStartIdentifierIsLocked
        ) {
          authState.authStartPhoneNumberFieldIsActive = false
          navigation.path = []
        }
      }
    }
    .padding(.bottom, 32)
  }

  private var subtitleString: LocalizedStringKey {
    if let appName = jsClerk.environment?.displayConfig.applicationName {
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
    await sendLink()
  }

  @MainActor
  private func sendLink() async {
    deliveryState = .sending

    do {
      switch mode {
      case .signIn(let factor):
        guard jsClerk.client.signIn.id != nil else {
          deliveryState = .idle
          navigation.path = []
          return
        }
        try await jsClerk.client.signIn.prepareFirstFactor(
          .init(
            strategy: .emailLink,
            emailAddressId: factor.emailAddressId,
            redirectUrl: ClerkJSRuntime.defaultOAuthRedirectURL.absoluteString
          )
        )

      case .signUp:
        guard jsClerk.client.signUp.id != nil else {
          deliveryState = .idle
          navigation.path = []
          return
        }
        try await jsClerk.client.signUp.prepareVerification(.init(strategy: .emailLink))
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
      error = ClerkClientError(message: "No email app is available on this device.", localizationBundle: .module)
      return
    }

    openURL(url) { accepted in
      if !accepted {
        Task { @MainActor in
          error = ClerkClientError(message: "No email app is available on this device.", localizationBundle: .module)
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
