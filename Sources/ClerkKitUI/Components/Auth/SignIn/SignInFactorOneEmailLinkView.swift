//
//  SignInFactorOneEmailLinkView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI
import UIKit

struct SignInFactorOneEmailLinkView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var deliveryState = DeliveryState.idle
  @State private var error: Error?

  let factor: Factor

  var signIn: SignIn? {
    clerk.auth.currentSignIn
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        headerSection

        VStack(spacing: 24) {
          openEmailAppButton
          statusSection

          resendSection
          useAnotherMethodButton
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
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

extension SignInFactorOneEmailLinkView {
  private var headerSection: some View {
    VStack(spacing: 8) {
      HeaderView(style: .title, text: "Check your email")
      HeaderView(style: .subtitle, text: subtitleString)

      if let identifier = factor.safeIdentifier {
        Button {
          navigation.path = []
        } label: {
          IdentityPreviewView(label: identifier)
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

  @ViewBuilder
  private var statusSection: some View {
    switch deliveryState {
    case .idle:
      EmptyView()
    case .sending:
      EmptyView()
    case .sent:
      HStack(spacing: 4) {
        Image("icon-check-circle", bundle: .module)
          .foregroundStyle(theme.colors.success)
        Text("Link sent", bundle: .module)
          .foregroundStyle(theme.colors.mutedForeground)
      }
      .font(theme.fonts.subheadline)
    case .failed(let error):
      ErrorText(error: error)
        .font(theme.fonts.subheadline)
    }
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
      .font(theme.fonts.subheadline)
      .monospacedDigit()
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

  private var useAnotherMethodButton: some View {
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

  private var isSendingLink: Bool {
    if case .sending = deliveryState {
      true
    } else {
      false
    }
  }

  @MainActor
  private func sendInitialLinkIfNeeded() async {
    guard signIn?.firstFactorVerification?.strategy != .emailLink else {
      deliveryState = .sent
      return
    }

    await sendLink()
  }

  @MainActor
  private func sendLink() async {
    guard let signIn else {
      navigation.path = []
      return
    }

    deliveryState = .sending

    do {
      _ = try await signIn.sendEmailLink(emailAddressId: factor.emailAddressId)
      deliveryState = .sent
    } catch {
      deliveryState = .failed(error)
      ClerkLogger.error("Failed to send email link", error: error)
    }
  }

  private func openEmailApp() {
    for urlString in ["message://", "mailto:"] {
      guard let url = URL(string: urlString) else { continue }
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
        return
      }
    }

    error = ClerkClientError(message: "No email app is available on this device.")
  }
}

extension SignInFactorOneEmailLinkView {
  enum DeliveryState {
    case idle
    case sending
    case sent
    case failed(Error)
  }
}

#Preview {
  SignInFactorOneEmailLinkView(
    factor: Factor(
      strategy: .emailLink,
      emailAddressId: "ema_123",
      safeIdentifier: "sam@clerk.dev"
    )
  )
  .clerkPreview()
}

#endif
