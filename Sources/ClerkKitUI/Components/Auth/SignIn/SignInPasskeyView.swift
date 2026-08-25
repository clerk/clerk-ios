//
//  SignInPasskeyView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SignInPasskeyView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation
  @Environment(AuthState.self) private var authState
  @Environment(\.authFlowRequestOwnerId) private var authFlowRequestOwnerId

  let factor: Factor
  let mode: SignInFactorMode

  @State private var passkeyInProgress = true
  @State private var automaticPasskeyAuthenticationHasStarted = false
  @State private var animateSymbol = false
  @State private var error: Error?

  private var signIn: SignIn? {
    clerk.auth.currentSignIn
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Use your passkey")
          HeaderView(style: .subtitle, text: "Using your passkey confirms it's you. Your device may ask for your fingerprint, face or screen lock.")

          if let identifier = factor.safeIdentifier {
            IdentityPreviewView(
              label: identifier.formattedAsPhoneNumberIfPossible,
              isEnabled: !authState.authStartFieldIsLocked(factor.authStartField)
            ) {
              authState.authStartPhoneNumberFieldIsActive = factor.authStartField == .phoneNumber
              navigation.path = []
            }
          }
        }
        .padding(.bottom, 32)

        if mode.showsClientTrustWarning {
          SignInClientTrustWarningView()
            .padding(.bottom, 32)
        }

        VStack(spacing: 24) {
          Image(systemName: "faceid")
            .resizable()
            .symbolRenderingMode(.palette)
            .symbolEffect(
              .bounce.down,
              options: .nonRepeating,
              value: animateSymbol
            )
            .foregroundStyle(theme.colors.foreground, theme.colors.primary)
            .scaledToFit()
            .frame(width: 64, height: 64)
            .foregroundStyle(theme.colors.mutedForeground)

          AsyncButton {
            await authWithPasskey()
          } label: { _ in
            ContinueButtonLabelView(isActive: passkeyInProgress)
          }
          .buttonStyle(.primary())
          .disabled(passkeyInProgress)
          .simultaneousGesture(TapGesture())

          Button(action: showAlternativeMethods) {
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
      await authenticateWithPasskeyAutomatically()
    }
  }
}

extension SignInPasskeyView {
  @MainActor
  static func performAutomaticPasskeyAuthentication(
    delay: () async throws -> Void = {
      try await Task.sleep(for: .seconds(0.5))
    },
    authenticate: () async -> Void
  ) async -> Bool {
    do {
      try await delay()
      try Task.checkCancellation()
    } catch {
      return false
    }

    await authenticate()
    return true
  }

  private func showAlternativeMethods() {
    navigation.path.append(
      mode.alternativeMethodsDestination(currentFactor: factor)
    )
  }

  private func authenticateWithPasskeyAutomatically() async {
    guard !automaticPasskeyAuthenticationHasStarted else { return }

    _ = await Self.performAutomaticPasskeyAuthentication {
      automaticPasskeyAuthenticationHasStarted = true
      await AuthFlowRequestScope.withOwner(authFlowRequestOwnerId) {
        await authWithPasskey()
      }
    }
  }

  private func authWithPasskey() async {
    guard var signIn else {
      navigation.path = []
      return
    }

    passkeyInProgress = true
    defer { passkeyInProgress = false }

    do {
      signIn = try await signIn.authenticateWithPasskey()

      error = nil
      navigation.setToStepForStatus(signIn: signIn)
    } catch {
      if Task.isCancelled || error.isCancellationError || error.isUserCancelledError { return }
      self.error = error
      ClerkLogger.error("Failed to authenticate with passkey", error: error)
    }
  }
}

#Preview {
  SignInPasskeyView(factor: .mockPasskey, mode: .firstFactor)
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#Preview("Localized") {
  SignInPasskeyView(factor: .mockPasskey, mode: .firstFactor)
    .clerkPreview()
    .environment(\.locale, .init(identifier: "fr"))
}

#endif
