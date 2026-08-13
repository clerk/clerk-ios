//
//  SessionTaskMfaVerifyTotpView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SessionTaskMfaVerifyTotpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(AuthNavigation.self) private var navigation
  @Environment(\.clerkTheme) private var theme

  @State private var code = ""
  @State private var error: Error?
  @State private var verificationState = CodeVerificationState.default
  @State private var otpFieldState = OTPField.FieldState.default
  @State private var backupCodes = [String]()
  @State private var verificationAttempts = OTPVerificationAttemptTracker()

  let token: AuthFlowPresentationToken

  @FocusState private var otpFieldIsFocused: Bool

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        SessionTaskHeaderSection(
          title: "Add authenticator application",
          subtitle: "Enter the verification code from your authenticator app."
        )
        .padding(.bottom, 24)

        OTPField(
          code: $code,
          fieldState: $otpFieldState,
          isFocused: $otpFieldIsFocused,
          accessibilityIdentifier: ClerkAccessibilityIdentifiers.Auth.SessionTask.Totp.code
        ) { submittedCode in
          await attempt(code: submittedCode)
        }
        .onAppear {
          verificationState = .default
          otpFieldIsFocused = true
        }
        .padding(.bottom, 24)

        CodeVerificationStatusView(state: verificationState)
          .padding(.bottom, 32)

        SecuredByClerkView()
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .padding(16)
    }
    .clerkErrorPresenting(
      $error,
      action: { error in
        if let clerkApiError = error as? ClerkAPIError, clerkApiError.code == "verification_already_verified" {
          return .init(text: "Continue") {
            verificationState = .verifying
            handleSuccessfulVerification()
          }
        }
        return nil
      }
    )
    .background(theme.colors.background)
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #elseif os(macOS)
    .macOSBackButton()
    #endif
    .preGlassSolidNavBar()
    .toolbar {
      UserButtonToolbarItem(presentationContext: .sessionTaskToolbar)
    }
  }

  private func attempt(code: String) async {
    guard clerk.authFlowPresentationIsCurrent(token),
          let user = clerk.user
    else {
      return
    }
    let attemptID = verificationAttempts.begin()
    verificationState = .verifying

    do {
      let totp = try await user.verifyTOTP(code: code)
      guard clerk.authFlowPresentationIsCurrent(token) else { return }
      guard verificationAttempts.complete(attemptID) else { return }
      guard !Task.isCancelled else {
        otpFieldState = .default
        verificationState = .default
        return
      }
      backupCodes = totp.backupCodes ?? []
      handleSuccessfulVerification()
    } catch {
      guard verificationAttempts.complete(attemptID) else { return }
      guard !Task.isCancelled, !error.isCancellationError else {
        otpFieldState = .default
        verificationState = .default
        return
      }
      otpFieldState = .error
      verificationState = .error(error)

      if let clerkError = error as? ClerkAPIError, clerkError.meta?["param_name"] == nil {
        self.error = clerkError
        otpFieldIsFocused = false
      }
    }
  }

  private func handleSuccessfulVerification() {
    guard clerk.authFlowPresentationIsCurrent(token) else { return }
    verificationState = .success
    if !backupCodes.isEmpty {
      navigation.appendPostAuthDestination(
        .backupCodes(
          backupCodes: backupCodes,
          mfaType: .authenticatorApp,
          token: token
        )
      )
    } else {
      _ = clerk.finishAuthFlowPresentation(token)
    }
  }
}

#endif
