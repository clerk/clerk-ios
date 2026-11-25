//
//  ReverificationBiometricView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct ReverificationBiometricView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(ReverificationFlow.self) private var flow
  @Environment(CodeLimiter.self) private var codeLimiter

  let factor: Factor
  let stage: ReverificationFlow.Stage

  @State private var biometryDisplayName = BiometryDisplayName.current()
  @State private var biometricInProgress = true
  @State private var automaticAttemptHasStarted = false
  @State private var error: Error?

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Verification required")
          HeaderView(style: .subtitle, text: "Use \(biometryDisplayName.value) to continue")
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          BiometricSignInButton(biometryDisplayName: biometryDisplayName, isActive: biometricInProgress) {
            await verifyWithBiometrics()
          }
          .disabled(biometricInProgress)
          .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Reverification.biometricButton)

          ReverificationUseAnotherMethodButton(factor: factor, stage: stage)
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .clerkErrorPresenting($error)
    .background(theme.colors.background)
    .task {
      guard !automaticAttemptHasStarted else { return }
      _ = await SignInPasskeyView.performAutomaticPasskeyAuthentication {
        automaticAttemptHasStarted = true
        await verifyWithBiometrics()
      }
      biometricInProgress = false
    }
  }

  private func verifyWithBiometrics() async {
    guard let session = flow.session else { return }

    biometricInProgress = true
    defer { biometricInProgress = false }

    codeLimiter.forgetLastCodeSent()
    do {
      let verification = try await session.verifyWithBiometrics(
        level: stage == .secondFactor ? .secondFactor : .firstFactor
      )
      error = nil
      await flow.handle(verification)
    } catch {
      if Task.isCancelled || error.isCancellationError || error.isUserCancelledError { return }
      self.error = error
      ClerkLogger.error("Failed to reverify with biometrics", error: error)
    }
  }
}

#Preview {
  ReverificationBiometricView(factor: Factor(strategy: .biometricCredential), stage: .firstFactor)
    .environment(ReverificationFlow(level: .firstFactor))
    .environment(CodeLimiter())
    .clerkPreview()
}

#endif
