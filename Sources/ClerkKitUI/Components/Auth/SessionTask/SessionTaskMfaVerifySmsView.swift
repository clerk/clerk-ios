//
//  SessionTaskMfaVerifySmsView.swift
//

#if os(iOS)

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

  let phoneNumber: ClerkKit.PhoneNumber

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
        Badge(key: "Two-step verification setup", style: .secondary)
          .padding(.bottom, 16)

        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Verify your phone number")
          HeaderView(style: .subtitle, text: "A text message containing a verification code will be sent to this phone number. Message and data rates may apply.")
        }
        .padding(.bottom, 16)

        Button {
          dismiss()
        } label: {
          IdentityPreviewView(label: phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible)
        }
        .buttonStyle(.secondary(config: .init(size: .small)))
        .simultaneousGesture(TapGesture())
        .padding(.bottom, 24)

        OTPField(
          code: $code,
          fieldState: $otpFieldState,
          isFocused: $otpFieldIsFocused
        ) { _ in
          await attempt()
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
    .clerkErrorPresenting($error)
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        UserButton(presentationContext: .sessionTaskToolbar)
      }
    }
  }

  private func attempt() async {
    verificationState = .verifying

    do {
      try await phoneNumber.verifyCode(code)
      try await handleSuccessfulVerification()
    } catch {
      otpFieldState = .error
      verificationState = .error(error)

      if let clerkError = error as? ClerkAPIError, clerkError.meta?["param_name"] == nil {
        self.error = clerkError
        otpFieldIsFocused = false
      }
    }
  }

  private func handleSuccessfulVerification() async throws {
    let reserved = try await phoneNumber.setReservedForSecondFactor()
    codeLimiter.clearRecord(for: codeLimiterIdentifier)
    verificationState = .success
    if let backupCodes = reserved.backupCodes, !backupCodes.isEmpty {
      navigation.path.append(.backupCodes(backupCodes: backupCodes, mfaType: .phoneCode))
    } else {
      navigation.handleSessionTaskCompletion(session: clerk.session)
    }
  }

  private func resend() async {
    code = ""
    verificationState = .default

    do {
      try await phoneNumber.sendCode()
      codeLimiter.recordCodeSent(for: codeLimiterIdentifier)
    } catch {
      otpFieldIsFocused = false
      self.error = error
      ClerkLogger.error("Failed to resend SMS code", error: error)
    }
  }
}

#endif
