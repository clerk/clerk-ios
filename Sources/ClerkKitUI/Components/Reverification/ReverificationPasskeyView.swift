//
//  ReverificationPasskeyView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct ReverificationPasskeyView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(ReverificationFlow.self) private var flow
  @Environment(CodeLimiter.self) private var codeLimiter

  let factor: Factor
  let stage: ReverificationFlow.Stage

  @State private var passkeyInProgress = true
  @State private var automaticAttemptHasStarted = false
  @State private var animateSymbol = false
  @State private var error: Error?

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Use your passkey")
          HeaderView(style: .subtitle, text: "Using your passkey confirms it's you. Your device may ask for your fingerprint, face or screen lock.")
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          Image(systemName: "faceid")
            .resizable()
            .symbolRenderingMode(.palette)
            .symbolEffect(.bounce.down, options: .nonRepeating, value: animateSymbol)
            .foregroundStyle(theme.colors.foreground, theme.colors.primary)
            .scaledToFit()
            .frame(width: 64, height: 64)

          AsyncButton {
            await verifyWithPasskey()
          } label: { _ in
            ContinueButtonLabelView(isActive: passkeyInProgress)
          }
          .buttonStyle(.primary())
          .disabled(passkeyInProgress)
          .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Reverification.continueButton)
          .simultaneousGesture(TapGesture())

          ReverificationUseAnotherMethodButton(factor: factor, stage: stage)
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .clerkErrorPresenting($error)
    .background(theme.colors.background)
    .onFirstAppear {
      animateSymbol.toggle()
    }
    .task {
      guard !automaticAttemptHasStarted else { return }
      _ = await SignInPasskeyView.performAutomaticPasskeyAuthentication {
        automaticAttemptHasStarted = true
        await verifyWithPasskey()
      }
      passkeyInProgress = false
    }
  }

  private func verifyWithPasskey() async {
    guard let session = flow.session else { return }

    passkeyInProgress = true
    defer { passkeyInProgress = false }

    codeLimiter.forgetLastCodeSent()
    do {
      let verification = try await session.verifyWithPasskey(
        preferImmediatelyAvailableCredentials: false,
        level: stage == .secondFactor ? .secondFactor : .firstFactor
      )
      error = nil
      await flow.handle(verification)
    } catch {
      if Task.isCancelled || error.isCancellationError || error.isUserCancelledError { return }
      self.error = error
      ClerkLogger.error("Failed to reverify with a passkey", error: error)
    }
  }
}

#Preview {
  ReverificationPasskeyView(factor: .mockPasskey, stage: .firstFactor)
    .environment(ReverificationFlow(level: .firstFactor))
    .environment(CodeLimiter())
    .clerkPreview()
}

#endif
