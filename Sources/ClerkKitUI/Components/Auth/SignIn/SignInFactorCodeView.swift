//
//  SignInFactorCodeView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SignInFactorCodeView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation
  @Environment(AuthState.self) private var authState
  @Environment(CodeLimiter.self) private var codeLimiter

  let factor: Factor
  var mode: FactorMode = .firstFactor

  @State private var code = ""
  @State private var error: Error?
  @State private var verificationState = VerificationState.default
  @State private var otpFieldState: OTPField.FieldState = .default
  @FocusState private var otpFieldIsFocused: Bool

  var signIn: SignIn? {
    clerk.auth.currentSignIn
  }

  var showResend: Bool {
    switch factor.strategy {
    case .totp:
      false
    default:
      verificationState.showResend
    }
  }

  var showUseAnotherMethod: Bool {
    switch factor.strategy {
    case .resetPasswordEmailCode, .resetPasswordPhoneCode:
      false
    default:
      true
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        headerSection

        if mode == .clientTrust {
          clientTrustWarning
        }

        inputSection

        SecuredByClerkView()
          .padding(.top, 32)
      }
      .padding(16)
    }
    .scrollDismissesKeyboard(.interactively)
    .clerkErrorPresenting($error)
    .background(theme.colors.background)
    .taskOnce {
      if signIn != nil, codeLimiter.isFirstRequest(for: codeLimiterIdentifier) {
        await prepare()
      }
    }
  }
}

// MARK: - Subviews

extension SignInFactorCodeView {
  private var headerSection: some View {
    VStack(spacing: 8) {
      HeaderView(style: .title, text: title)
      HeaderView(style: .subtitle, text: subtitleString)

      if let identifier = factor.safeIdentifier {
        Button {
          navigation.path = []
        } label: {
          IdentityPreviewView(label: identifier.formattedAsPhoneNumberIfPossible)
        }
        .buttonStyle(.secondary(config: .init(size: .small)))
        .simultaneousGesture(TapGesture())
      }
    }
    .padding(.bottom, 32)
  }

  private var clientTrustWarning: some View {
    Text("You're signing in from a new device. We're asking for verification to keep your account secure.", bundle: .module)
      .foregroundStyle(theme.colors.warning)
      .font(theme.fonts.subheadline)
      .multilineTextAlignment(.center)
      .padding(.bottom, 32)
  }

  private var inputSection: some View {
    VStack(spacing: 24) {
      otpInputSection

      verificationStatusView

      if showResend {
        resendSection
      }

      if showUseAnotherMethod {
        useAnotherMethodButton
      }
    }
  }

  private var otpInputSection: some View {
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
  }

  private var verificationStatusView: some View {
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
  }

  private var resendSection: some View {
    ResendCodeButton(
      codeLimiter: codeLimiter,
      identifier: codeLimiterIdentifier,
      theme: theme
    ) {
      await prepare()
    }
  }

  private var useAnotherMethodButton: some View {
    Button {
      if mode.usesSecondFactorAPI {
        navigation.path.append(
          AuthView.Destination.signInFactorTwoUseAnotherMethod(
            currentFactor: factor
          )
        )
      } else {
        navigation.path.append(
          AuthView.Destination.signInFactorOneUseAnotherMethod(
            currentFactor: factor
          )
        )
      }
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

// MARK: - Computed Properties

extension SignInFactorCodeView {
  private var title: LocalizedStringKey {
    switch factor.strategy {
    case .emailCode:
      "Check your email"
    case .phoneCode:
      "Check your phone"
    case .resetPasswordEmailCode, .resetPasswordPhoneCode:
      "Reset password"
    case .totp:
      "Two-step verification"
    default:
      ""
    }
  }

  private var subtitleString: LocalizedStringKey {
    switch factor.strategy {
    case .resetPasswordEmailCode:
      "First, enter the code sent to your email address"
    case .resetPasswordPhoneCode:
      "First, enter the code sent to your phone"
    case .totp:
      "To continue, please enter the verification code generated by your authenticator app"
    default:
      if let appName = clerk.environment?.displayConfig.applicationName {
        "to continue to \(appName)"
      } else {
        "to continue"
      }
    }
  }
}

// MARK: - Enums

extension SignInFactorCodeView {
  enum FactorMode {
    case firstFactor
    case secondFactor
    case clientTrust

    var usesSecondFactorAPI: Bool {
      switch self {
      case .firstFactor:
        false
      case .secondFactor, .clientTrust:
        true
      }
    }
  }

  enum VerificationState {
    case `default`
    case verifying
    case success
    case error(Error)

    var showResend: Bool {
      switch self {
      case .default, .error:
        true
      case .verifying, .success:
        false
      }
    }
  }
}

// MARK: - Helpers

extension SignInFactorCodeView {
  private var codeLimiterIdentifier: String {
    guard let signIn else { return "" }
    return signIn.id + (factor.safeIdentifier ?? factor.strategy.rawValue)
  }
}

// MARK: - Actions

extension SignInFactorCodeView {
  func prepare() async {
    code = ""
    verificationState = .default

    guard var signIn else {
      navigation.path = []
      return
    }

    do {
      switch factor.strategy {
      case .emailCode:
        if mode.usesSecondFactorAPI {
          signIn = try await signIn.sendMfaEmailCode(emailAddressId: factor.emailAddressId)
        } else {
          signIn = try await signIn.sendEmailCode(emailAddressId: factor.emailAddressId)
        }

      case .phoneCode:
        if mode.usesSecondFactorAPI {
          signIn = try await signIn.sendMfaPhoneCode(phoneNumberId: factor.phoneNumberId)
        } else {
          signIn = try await signIn.sendPhoneCode(phoneNumberId: factor.phoneNumberId)
        }

      case .resetPasswordEmailCode:
        signIn = try await signIn.sendResetPasswordEmailCode(emailAddressId: factor.emailAddressId)

      case .resetPasswordPhoneCode:
        signIn = try await signIn.sendResetPasswordPhoneCode(phoneNumberId: factor.phoneNumberId)

      default:
        break
      }

      codeLimiter.recordCodeSent(for: codeLimiterIdentifier)
    } catch {
      otpFieldIsFocused = false
      self.error = error
      ClerkLogger.error("Failed to prepare factor for sign in", error: error)
    }
  }

  func attempt() async {
    guard var signIn else {
      navigation.path = []
      return
    }

    otpFieldState = .default
    verificationState = .verifying

    do {
      signIn = try await attemptVerification(signIn: signIn)
      otpFieldIsFocused = false
      verificationState = .success
      navigation.setToStepForStatus(signIn: signIn)
    } catch {
      handleVerificationError(error)
    }
  }

  private func attemptVerification(signIn: SignIn) async throws -> SignIn {
    switch factor.strategy {
    case .emailCode:
      if mode.usesSecondFactorAPI {
        return try await signIn.verifyMfaCode(code, type: .emailCode)
      } else {
        return try await signIn.verifyCode(code)
      }
    case .phoneCode:
      if mode.usesSecondFactorAPI {
        return try await signIn.verifyMfaCode(code, type: .phoneCode)
      } else {
        return try await signIn.verifyCode(code)
      }
    case .resetPasswordEmailCode, .resetPasswordPhoneCode:
      return try await signIn.verifyCode(code)
    case .totp:
      return try await signIn.verifyMfaCode(code, type: .totp)
    default:
      throw ClerkClientError(message: "Unknown code verification method. Please use another method.")
    }
  }

  private func handleVerificationError(_ error: Error) {
    otpFieldState = .error
    verificationState = .error(error)

    if let clerkError = error as? ClerkAPIError, clerkError.meta?["param_name"] == nil {
      self.error = error
      ClerkLogger.error("Failed to attempt factor for sign in", error: error)
      otpFieldIsFocused = false
    }
  }
}

// MARK: - ResendCodeButton

/// A leaf view that isolates timer-driven countdown updates.
/// Only this view re-renders every second, not the parent SignInFactorCodeView.
private struct ResendCodeButton: View {
  let codeLimiter: CodeLimiter
  let identifier: String
  let theme: ClerkTheme
  let action: () async -> Void

  private var remainingSeconds: Int {
    codeLimiter.remainingCooldown(for: identifier)
  }

  var body: some View {
    AsyncButton {
      await action()
    } label: { isRunning in
      HStack(spacing: 2) {
        Text("Didn't receive a code?", bundle: .module)
        Group {
          if remainingSeconds > 0 {
            Text("Resend (\(remainingSeconds))", bundle: .module)
              .foregroundStyle(theme.colors.mutedForeground)
          } else {
            Text("Resend", bundle: .module)
              .foregroundStyle(theme.colors.primary)
          }
        }
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

#Preview("Email Code") {
  SignInFactorCodeView(factor: .mockEmailCode)
    .clerkPreview()
}

#Preview("Phone Code") {
  SignInFactorCodeView(factor: .mockPhoneCode)
    .clerkPreview()
}

#Preview("Reset Password Email Code") {
  SignInFactorCodeView(factor: .mockResetPasswordEmailCode)
    .clerkPreview()
}

#Preview("Reset Password Phone Code") {
  SignInFactorCodeView(factor: .mockResetPasswordPhoneCode)
    .clerkPreview()
}

#Preview("TOTP Code") {
  SignInFactorCodeView(factor: .mockTotp)
    .clerkPreview()
}

#endif
