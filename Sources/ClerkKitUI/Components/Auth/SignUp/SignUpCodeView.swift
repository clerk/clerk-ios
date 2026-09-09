//
//  SignUpCodeView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SignUpCodeView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation
  @Environment(AuthState.self) private var authState
  @Environment(CodeLimiter.self) private var codeLimiter

  @State private var code = ""
  @State private var verificationState = CodeVerificationState.default
  @State private var otpFieldState = OTPField.FieldState.default
  @State private var error: Error?

  @FocusState private var otpFieldIsFocused: Bool

  private var remainingSeconds: Int {
    guard let signUp else { return 0 }
    return codeLimiter.remainingCooldown(for: codeLimiterIdentifier(signUp))
  }

  var signUp: SignUp? {
    clerk.signUp.id == nil ? nil : clerk.signUp
  }

  enum Field: Hashable {
    case email(String)
    case phone(String)

    var title: LocalizedStringKey {
      switch self {
      case .email:
        "Check your email"
      case .phone:
        "Check your phone"
      }
    }

    var identityPreviewString: String {
      switch self {
      case let .email(emailAddress):
        emailAddress
      case let .phone(phoneNumber):
        phoneNumber.formattedAsPhoneNumberIfPossible
      }
    }

    var authStartField: AuthStartField {
      switch self {
      case .email:
        .emailOrUsername
      case .phone:
        .phoneNumber
      }
    }
  }

  var resendString: LocalizedStringKey {
    if remainingSeconds > 0 {
      "Resend (\(remainingSeconds))"
    } else {
      "Resend"
    }
  }

  private var showResend: Bool {
    verificationState.showResend
  }

  private func codeLimiterIdentifier(_ signUp: SignUp) -> String {
    (signUp.id ?? signUp.handle.id) + field.identityPreviewString
  }

  let field: Field

  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: field.title)
          IdentityPreviewView(
            label: field.identityPreviewString,
            isEnabled: !authState.authStartFieldIsLocked(field.authStartField)
          ) {
            authState.authStartPhoneNumberFieldIsActive = field.authStartField == .phoneNumber
            navigation.path = []
          }
        }

        VStack(spacing: 24) {
          OTPField(
            code: $code,
            fieldState: $otpFieldState,
            isFocused: $otpFieldIsFocused,
            accessibilityIdentifier: ClerkAccessibilityIdentifiers.Auth.SignUp.code
          ) { submittedCode in
            await attempt(code: submittedCode)
          }
          .onAppear {
            verificationState = .default
            otpFieldIsFocused = true
          }

          CodeVerificationStatusView(state: verificationState)

          if showResend {
            AsyncButton {
              await prepare()
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

        SecuredByClerkView()
      }
      .padding(16)
    }
    #if os(iOS)
    .scrollDismissesKeyboard(.interactively)
    #endif
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Sign up", bundle: .module)
          .font(theme.fonts.headline)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .background(theme.colors.background)
    .clerkErrorPresenting(
      $error,
      action: { error in
        if let clerkApiError = (error as? CoreError)?.errors.first, clerkApiError.code == "verification_already_verified", let signUp {
          return .init(text: "Continue") {
            navigation.setToStepForStatus(signUp: signUp)
          }
        }
        return nil
      }
    )
    .taskOnce {
      if let signUp, codeLimiter.isFirstRequest(for: codeLimiterIdentifier(signUp)) {
        await prepare()
      }
    }
  }
}

extension SignUpCodeView {
  func prepare() async {
    code = ""
    otpFieldState = .default
    verificationState = .default

    guard let signUp else {
      navigation.path = []
      return
    }

    do {
      switch field {
      case .email:
        try await signUp.verifications.sendEmailCode()
      case .phone:
        try await signUp.verifications.sendPhoneCode()
      }

      codeLimiter.recordCodeSent(for: codeLimiterIdentifier(signUp))
    } catch {
      otpFieldIsFocused = false
      self.error = error
      ClerkLogger.error("Failed to prepare verification for sign up", error: error)
    }
  }

  func attempt(code: String) async -> OTPSubmissionDisposition {
    guard let signUp else {
      navigation.path = []
      return .stop
    }

    otpFieldState = .default
    verificationState = .verifying

    do {
      switch field {
      case .email:
        try await signUp.verifications.verifyEmailCode(.init(code: code))
      case .phone:
        try await signUp.verifications.verifyPhoneCode(.init(code: code))
      }

      try await clerk.finalizeForPresentation(.signUp(signUp))
      guard !Task.isCancelled else {
        otpFieldState = .default
        verificationState = .default
        return .stop
      }
      otpFieldIsFocused = false
      verificationState = .success
      navigation.setToStepForStatus(signUp: signUp)
      return .stop
    } catch {
      guard !Task.isCancelled, !error.isCancellationError else {
        otpFieldState = .default
        verificationState = .default
        return .stop
      }
      otpFieldState = .error
      verificationState = .error(error)

      if let clerkApiError = (error as? CoreError)?.errors.first, clerkApiError.meta?.paramName == nil {
        self.error = error
        otpFieldIsFocused = false
      }

      return error.otpSubmissionDisposition
    }
  }
}

#Preview("Email") {
  NavigationStack {
    SignUpCodeView(field: .email("user@email.com"))
  }
  .environment(\.clerkTheme, .clerk)
}

#Preview("Phone") {
  NavigationStack {
    SignUpCodeView(field: .phone("+15555550100"))
  }
  .environment(\.clerkTheme, .clerk)
}

#endif
