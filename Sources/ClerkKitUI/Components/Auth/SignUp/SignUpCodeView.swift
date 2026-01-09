//
//  SignUpCodeView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/20/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SignUpCodeView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation
  @Environment(AuthState.self) private var authState
  @Environment(CodeLimiter.self) private var codeLimiter

  @State private var code = ""
  @State private var verificationState = VerificationState.default
  @State private var otpFieldState = OTPField.FieldState.default
  @State private var error: Error?

  @FocusState private var otpFieldIsFocused: Bool

  private var remainingSeconds: Int {
    guard let signUp else { return 0 }
    return codeLimiter.remainingCooldown(for: codeLimiterIdentifier(signUp))
  }

  var signUp: SignUp? {
    clerk.client?.signUp
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

  var resendString: LocalizedStringKey {
    if remainingSeconds > 0 {
      "Resend (\(remainingSeconds))"
    } else {
      "Resend"
    }
  }

  private func codeLimiterIdentifier(_ signUp: SignUp) -> String {
    signUp.id + field.identityPreviewString
  }

  let field: Field

  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: field.title)
          Button {
            navigation.path = []
          } label: {
            IdentityPreviewView(label: field.identityPreviewString)
          }
          .buttonStyle(.secondary(config: .init(size: .small)))
          .simultaneousGesture(TapGesture())
        }

        VStack(spacing: 24) {
          OTPField(code: $code, fieldState: $otpFieldState, isFocused: $otpFieldIsFocused) { _ in
            await attempt()
          }
          .onAppear {
            verificationState = .default
            otpFieldIsFocused = true
          }

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

          if verificationState.showResend {
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
    .scrollDismissesKeyboard(.interactively)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Sign up", bundle: .module)
          .font(theme.fonts.headline)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .background(theme.colors.background)
    .clerkErrorPresenting(
      $error,
      action: { error in
        if let clerkApiError = error as? ClerkAPIError, clerkApiError.code == "verification_already_verified", let signUp {
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

    guard var signUp else {
      navigation.path = []
      return
    }

    do {
      switch field {
      case .email:
        signUp = try await signUp.sendEmailCode()
      case .phone:
        signUp = try await signUp.sendPhoneCode()
      }

      codeLimiter.recordCodeSent(for: codeLimiterIdentifier(signUp))
    } catch {
      otpFieldIsFocused = false
      self.error = error
      ClerkLogger.error("Failed to prepare verification for sign up", error: error)
    }
  }

  func attempt() async {
    guard var signUp else {
      navigation.path = []
      return
    }

    otpFieldState = .default
    verificationState = .verifying

    do {
      switch field {
      case .email:
        signUp = try await signUp.verifyEmailCode(code)
      case .phone:
        signUp = try await signUp.verifyPhoneCode(code)
      }

      otpFieldIsFocused = false
      verificationState = .success
      navigation.setToStepForStatus(signUp: signUp)
    } catch {
      otpFieldState = .error
      verificationState = .error(error)

      if let clerkApiError = error as? ClerkAPIError, clerkApiError.meta?["param_name"] == nil {
        self.error = clerkApiError
        otpFieldIsFocused = false
      }
    }
  }
}

#Preview("Email") {
  NavigationStack {
    SignUpCodeView(field: .email(EmailAddress.mock.emailAddress))
  }
  .environment(\.clerkTheme, .clerk)
}

#Preview("Phone") {
  NavigationStack {
    SignUpCodeView(field: .phone(PhoneNumber.mock.phoneNumber))
      .environment(\.clerkTheme, .clerk)
  }
}

#endif
