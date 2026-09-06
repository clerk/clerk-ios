//
//  SignUpCodeView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkJSCore
import ClerkKit
import SwiftUI

struct SignUpCodeView: View {
  @SwiftUI.Environment(ClerkJSCore.Clerk.self) private var jsClerk
  @SwiftUI.Environment(\.clerkTheme) private var theme
  @SwiftUI.Environment(AuthNavigation.self) private var navigation
  @SwiftUI.Environment(AuthState.self) private var authState
  @SwiftUI.Environment(CodeLimiter.self) private var codeLimiter

  @State private var code = ""
  @State private var verificationState = CodeVerificationState.default
  @State private var otpFieldState = OTPField.FieldState.default
  @State private var error: Error?

  @FocusState private var otpFieldIsFocused: Bool

  private var remainingSeconds: Int {
    guard signUp.id != nil else { return 0 }
    return codeLimiter.remainingCooldown(for: codeLimiterIdentifier)
  }

  var signUp: ClerkJSCore.Clerk.SignUp {
    jsClerk.client.signUp
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

    var strategy: ClerkJSCore.Clerk.SignUp.Strategy {
      switch self {
      case .email:
        .emailCode
      case .phone:
        .phoneCode
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

  private var codeLimiterIdentifier: String {
    (signUp.id ?? "") + field.identityPreviewString
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
        if let clerkApiError = error as? ClerkKit.ClerkAPIError, clerkApiError.code == "verification_already_verified", signUp.id != nil {
          return .init(text: "Continue") {
            navigation.setToStepForStatus(signUp: JSCoreAuthMapping.signUp(from: signUp))
          }
        }
        return nil
      }
    )
    .taskOnce {
      if signUp.id != nil, codeLimiter.isFirstRequest(for: codeLimiterIdentifier) {
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

    guard signUp.id != nil else {
      navigation.path = []
      return
    }

    do {
      _ = try await signUp.prepareVerification(.init(strategy: field.strategy))
      codeLimiter.recordCodeSent(for: codeLimiterIdentifier)
    } catch {
      otpFieldIsFocused = false
      self.error = error
      ClerkLogger.error("Failed to prepare verification for sign up", error: error)
    }
  }

  func attempt(code: String) async -> OTPSubmissionDisposition {
    guard signUp.id != nil else {
      navigation.path = []
      return .stop
    }

    otpFieldState = .default
    verificationState = .verifying

    do {
      let jsSignUp = try await signUp.attemptVerification(.init(strategy: field.strategy, code: code))
      let kitSignUp = JSCoreAuthMapping.signUp(from: jsSignUp)
      try await JSCoreAuthMapping.activateIfComplete(kitSignUp, using: jsClerk)

      guard !Task.isCancelled else {
        otpFieldState = .default
        verificationState = .default
        return .stop
      }
      otpFieldIsFocused = false
      verificationState = .success
      navigation.setToStepForStatus(signUp: kitSignUp)
      return .stop
    } catch {
      guard !Task.isCancelled, !error.isCancellationError else {
        otpFieldState = .default
        verificationState = .default
        return .stop
      }
      otpFieldState = .error
      verificationState = .error(error)

      if let clerkApiError = error as? ClerkKit.ClerkAPIError, clerkApiError.meta?["param_name"] == nil {
        self.error = clerkApiError
        otpFieldIsFocused = false
      }

      return error.otpSubmissionDisposition
    }
  }
}

#Preview("Email") {
  NavigationStack {
    SignUpCodeView(field: .email(EmailAddress.mock.emailAddress))
  }
  .environment(\.clerkTheme, .clerk)
  .clerkPreview()
}

#Preview("Phone") {
  NavigationStack {
    SignUpCodeView(field: .phone(PhoneNumber.mock.phoneNumber))
  }
  .environment(\.clerkTheme, .clerk)
  .clerkPreview()
}

#endif
