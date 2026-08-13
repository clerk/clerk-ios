//
//  SessionTaskMfaVerifySmsView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SessionTaskMfaVerifySmsView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(AuthNavigation.self) private var navigation
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(CodeLimiter.self) private var codeLimiter

  @State private var code = ""
  @State private var error: Error?
  @State private var verificationState = CodeVerificationState.default
  @State private var otpFieldState = OTPField.FieldState.default

  @FocusState private var otpFieldIsFocused: Bool

  let phoneNumber: PhoneNumber
  let token: AuthFlowPresentationToken

  private var codeLimiterIdentifier: String {
    phoneNumber.phoneNumber
  }

  private var remainingSeconds: Int {
    codeLimiter.remainingCooldown(for: codeLimiterIdentifier)
  }

  private var resendString: LocalizedStringKey {
    if remainingSeconds > 0 {
      "Resend (\(remainingSeconds))"
    } else {
      "Resend"
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        SessionTaskHeaderSection(
          title: "Verify your phone number",
          subtitle: "Enter the verification code sent to"
        )
        .padding(.bottom, 16)

        IdentityPreviewView(label: phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible) {
          dismiss()
        }
        .padding(.bottom, 24)

        OTPField(
          code: $code,
          fieldState: $otpFieldState,
          isFocused: $otpFieldIsFocused,
          accessibilityIdentifier: ClerkAccessibilityIdentifiers.Auth.SessionTask.Sms.code
        ) { submittedCode in
          await attempt(code: submittedCode)
        }
        .onAppear {
          verificationState = .default
          otpFieldIsFocused = true
        }
        .padding(.bottom, 16)

        CodeVerificationStatusView(state: verificationState)
          .padding(.bottom, 16)

        if verificationState.showResend {
          AsyncButton {
            await resend()
          } label: { isRunning in
            HStack(spacing: 2) {
              Text("Didn't receive a code?", bundle: .module)
              Text(resendString, bundle: .module)
                .foregroundStyle(
                  remainingSeconds > 0
                    ? theme.colors.mutedForeground
                    : theme.colors.primary
                )
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: remainingSeconds)
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
          .disabled(remainingSeconds > 0)
          .simultaneousGesture(TapGesture())
          .padding(.bottom, 32)
        }

        SecuredByClerkView()
      }
      .padding(16)
    }
    .clerkErrorPresenting(
      $error,
      action: { error in
        if let clerkApiError = error as? ClerkAPIError, clerkApiError.code == "verification_already_verified" {
          return .init(text: "Continue") {
            Task {
              do {
                verificationState = .verifying
                try await handleSuccessfulVerification()
              } catch {
                self.error = error
              }
            }
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

  private func attempt(code: String) async -> OTPSubmissionDisposition {
    guard clerk.authFlowPresentationIsCurrent(token) else { return .stop }
    verificationState = .verifying

    do {
      try await phoneNumber.verifyCode(code)
      guard clerk.authFlowPresentationIsCurrent(token) else { return .stop }
      guard !Task.isCancelled else {
        otpFieldState = .default
        verificationState = .default
        return .stop
      }
      try await handleSuccessfulVerification()
      return .stop
    } catch {
      guard !Task.isCancelled, !error.isCancellationError else {
        otpFieldState = .default
        verificationState = .default
        return .stop
      }
      otpFieldState = .error
      verificationState = .error(error)

      if let clerkError = error as? ClerkAPIError, clerkError.meta?["param_name"] == nil {
        self.error = clerkError
        otpFieldIsFocused = false
      }

      return error.otpSubmissionDisposition
    }
  }

  private func handleSuccessfulVerification() async throws {
    guard clerk.authFlowPresentationIsCurrent(token) else { return }
    let reserved = try await phoneNumber.setReservedForSecondFactor()
    guard clerk.authFlowPresentationIsCurrent(token), !Task.isCancelled else { return }
    codeLimiter.clearRecord(for: codeLimiterIdentifier)
    verificationState = .success
    if let backupCodes = reserved.backupCodes, !backupCodes.isEmpty {
      navigation.appendPostAuthDestination(
        .backupCodes(
          backupCodes: backupCodes,
          mfaType: .phoneCode,
          token: token
        )
      )
    } else {
      _ = clerk.finishAuthFlowPresentation(token)
    }
  }

  private func resend() async {
    guard clerk.authFlowPresentationIsCurrent(token) else { return }
    code = ""
    verificationState = .default

    do {
      try await phoneNumber.sendCode()
      guard clerk.authFlowPresentationIsCurrent(token) else { return }
      codeLimiter.recordCodeSent(for: codeLimiterIdentifier)
    } catch {
      otpFieldIsFocused = false
      self.error = error
      ClerkLogger.error("Failed to resend SMS code", error: error)
    }
  }
}

#endif
