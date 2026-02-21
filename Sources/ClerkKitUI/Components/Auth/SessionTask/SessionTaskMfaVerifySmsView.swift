//
//  SessionTaskMfaVerifySmsView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SessionTaskMfaVerifySmsView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(CodeLimiter.self) private var codeLimiter

  @State private var code = ""
  @State private var error: Error?
  @State private var verificationState = VerificationState.default
  @State private var otpFieldState = OTPField.FieldState.default
  @State private var backupCodes: [String]?
  @State private var showBackupCodes = false

  @FocusState private var otpFieldIsFocused: Bool

  let phoneNumber: ClerkKit.PhoneNumber
  let onDone: () -> Void

  enum VerificationState {
    case `default`
    case verifying
    case success
    case error(Error)
  }

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

        Group {
          switch verificationState {
          case .verifying:
            HStack(spacing: 4) {
              SpinnerView()
                .frame(width: 16, height: 16)
              Text("Verifying...", bundle: .module)
            }
            .foregroundStyle(theme.colors.mutedForeground)
          case .success:
            HStack(spacing: 4) {
              Image("icon-check-circle", bundle: .module)
                .foregroundStyle(theme.colors.success)
              Text("Success", bundle: .module)
                .foregroundStyle(theme.colors.mutedForeground)
            }
          case let .error(error):
            ErrorText(error: error)
          default:
            EmptyView()
          }
        }
        .font(theme.fonts.subheadline)
        .padding(.bottom, 16)

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

        SecuredByClerkView()
      }
      .padding(16)
    }
    .clerkErrorPresenting($error)
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        UserButton(presentationContext: .sessionTaskToolbar)
      }
    }
    .navigationDestination(isPresented: $showBackupCodes) {
      if let backupCodes {
        SessionTaskBackupCodesView(backupCodes: backupCodes, mfaType: .phoneCode) {
          onDone()
        }
      }
    }
  }

  private func attempt() async {
    verificationState = .verifying

    do {
      try await phoneNumber.verifyCode(code)
      let reserved = try await phoneNumber.setReservedForSecondFactor()
      codeLimiter.clearRecord(for: codeLimiterIdentifier)
      verificationState = .success
      backupCodes = reserved.backupCodes ?? []
      showBackupCodes = true
    } catch {
      otpFieldState = .error
      verificationState = .error(error)

      if let clerkError = error as? ClerkAPIError, clerkError.meta?["param_name"] == nil {
        self.error = clerkError
        otpFieldIsFocused = false
      }
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
