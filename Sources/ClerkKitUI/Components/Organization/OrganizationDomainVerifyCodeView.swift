//
//  OrganizationDomainVerifyCodeView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationDomainVerifyCodeView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(CodeLimiter.self) private var codeLimiter

  let emailAddress: String
  let onVerified: @MainActor () -> Void

  @State private var currentDomain: OrganizationDomain
  @State private var code = ""
  @State private var error: Error?
  @State private var verificationState = CodeVerificationState.default
  @State private var otpFieldState = OTPField.FieldState.default
  @FocusState private var otpFieldIsFocused: Bool

  init(
    domain: OrganizationDomain,
    emailAddress: String,
    onVerified: @escaping @MainActor () -> Void
  ) {
    self.emailAddress = emailAddress
    self.onVerified = onVerified
    _currentDomain = State(initialValue: domain)
  }

  private var remainingSeconds: Int {
    codeLimiter.remainingCooldown(for: emailAddress)
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
      VStack(spacing: 24) {
        Text("A verification code was sent to \(emailAddress). Enter the code to continue.", bundle: .module)
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)

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

        CodeVerificationStatusView(state: verificationState)

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
        }
      }
      .padding(24)
    }
    .clerkErrorPresenting($error)
    .presentationBackground(theme.colors.background)
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Verify domain", bundle: .module)
          .font(theme.fonts.headline)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    .taskOnce {
      codeLimiter.recordCodeSent(for: emailAddress)
    }
  }

  @MainActor
  private func resend() async {
    code = ""
    otpFieldState = .default
    verificationState = .default

    do {
      currentDomain = try await currentDomain.sendEmailCode(affiliationEmailAddress: emailAddress)
      codeLimiter.recordCodeSent(for: emailAddress)
    } catch {
      otpFieldIsFocused = false
      self.error = error
      ClerkLogger.error("Failed to resend organization domain verification code", error: error)
    }
  }

  @MainActor
  private func attempt() async {
    verificationState = .verifying

    do {
      try await currentDomain.verifyCode(code)
      codeLimiter.clearRecord(for: emailAddress)
      verificationState = .success
      onVerified()
    } catch {
      otpFieldState = .error
      verificationState = .error(error)

      if let clerkError = error as? ClerkAPIError, clerkError.meta?["param_name"] == nil {
        self.error = clerkError
        otpFieldIsFocused = false
      }
    }
  }
}

#endif
