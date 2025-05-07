//
//  SignInFactorOneCodeView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

#if os(iOS)

  import Factory
  import SwiftUI

  struct SignInFactorOneCodeView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.authState) private var authState
    @Environment(\.dismissKeyboard) private var dismissKeyboard

    @State private var code = ""
    @State private var error: Error?
    @State private var remainingSeconds: Int = 30
    @State private var timer: Timer?
    @State private var verificationState = VerificationState.default

    let factor: Factor

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

    var signIn: SignIn? {
      clerk.client?.signIn
    }

    var title: LocalizedStringKey {
      switch factor.strategy {
      case "email_code":
        "Check your email"
      case "phone_code":
        "Check your phone"
      case "reset_password_email_code", "reset_password_phone_code":
        "Reset password"
      default:
        ""
      }
    }

    var subtitleString: LocalizedStringKey {
      switch factor.strategy {
      case "reset_password_email_code":
        "First, enter the code sent to your email address"
      case "reset_password_phone_code":
        "First, enter the code sent to your phone"
      default:
        if let appName = clerk.environment.displayConfig?.applicationName {
          "to continue to \(appName)"
        } else {
          "to continue"
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

    var body: some View {
      ScrollView {
        VStack(spacing: 0) {
          AppLogoView()
            .frame(maxHeight: 44)
            .padding(.bottom, 24)

          VStack(spacing: 8) {
            HeaderView(style: .title, text: title)
            HeaderView(style: .subtitle, text: subtitleString)

            if let identifier = factor.safeIdentifier {
              Button {
                authState.path = NavigationPath()
              } label: {
                IdentityPreviewView(label: identifier.formattedAsPhoneNumberIfPossible)
              }
              .buttonStyle(.secondary(config: .init(size: .small)))
              .simultaneousGesture(TapGesture())
            }
          }
          .padding(.bottom, 32)

          VStack(spacing: 24) {
            OTPField(code: $code) { code in
              do {
                try await attempt()
                return .default
              } catch {
                verificationState = .error(error)
                return .error
              }
            }
            .toolbar {
              ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                  dismissKeyboard()
                }
                .tint(theme.colors.text)
              }
            }

            Group {
              switch verificationState {
              case .verifying:
                HStack(spacing: 4) {
                  SpinnerView()
                    .frame(width: 16, height: 16)
                  Text("Verifying...", bundle: .module)
                }
                .foregroundStyle(theme.colors.textSecondary)
              case .success:
                HStack(spacing: 4) {
                  Image("icon-check-circle", bundle: .module)
                    .foregroundStyle(theme.colors.success)
                  Text("Success", bundle: .module)
                    .foregroundStyle(theme.colors.textSecondary)
                }
              case .error(let error):
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
                HStack(spacing: 0) {
                  Text("Didn't recieve a code? ", bundle: .module)
                  Text(resendString, bundle: .module)
                    .foregroundStyle(
                      remainingSeconds > 0
                        ? theme.colors.textSecondary
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

            Button {
              authState.path.append(
                AuthState.Destination.signInFactorOneUseAnotherMethod(
                  currentFactor: factor
                )
              )
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
          .padding(.bottom, 32)

          SecuredByClerkView()
        }
        .padding(16)
      }
      .background(theme.colors.background)
      .taskOnce {
        startTimer()
        if authState.lastCodeSentAt[factor] == nil {
          await prepare()
        }
      }
    }
  }

  extension SignInFactorOneCodeView {

    func startTimer() {
      updateRemainingSeconds()
      self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        Task { @MainActor in
          updateRemainingSeconds()
        }
      }
      RunLoop.current.add(timer!, forMode: .common)
    }

    func updateRemainingSeconds() {
      guard let lastCodeSentAt = authState.lastCodeSentAt[factor] else {
        return
      }

      let elapsed = Int(Date.now.timeIntervalSince(lastCodeSentAt))
      remainingSeconds = max(0, 30 - elapsed)
    }

    func prepare() async {
      code = ""

      guard let signIn else {
        authState.path = NavigationPath()
        return
      }

      do {
        switch factor.strategy {
        case "email_code":
          try await signIn.prepareFirstFactor(
            strategy: .emailCode(emailAddressId: factor.emailAddressId)
          )
        case "phone_code":
          try await signIn.prepareFirstFactor(
            strategy: .phoneCode(phoneNumberId: factor.phoneNumberId)
          )

        case "reset_password_email_code":
          try await signIn.prepareFirstFactor(
            strategy: .resetPasswordEmailCode(emailAddressId: factor.emailAddressId)
          )

        case "reset_password_phone_code":
          try await signIn.prepareFirstFactor(
            strategy: .resetPasswordPhoneCode(phoneNumberId: factor.phoneNumberId)
          )
        default:
          return
        }

        authState.lastCodeSentAt[factor] = .now
        updateRemainingSeconds()
      } catch {
        verificationState = .error(error)
      }
    }

    func attempt() async throws {
      guard var signIn else {
        authState.path = NavigationPath()
        return
      }

      verificationState = .verifying

      switch factor.strategy {
      case "email_code":
        signIn = try await signIn.attemptFirstFactor(strategy: .emailCode(code: code))
      case "phone_code":
        signIn = try await signIn.attemptFirstFactor(strategy: .phoneCode(code: code))
      case "reset_password_email_code":
        signIn = try await signIn.attemptFirstFactor(strategy: .resetPasswordEmailCode(code: code))
      case "reset_password_phone_code":
        signIn = try await signIn.attemptFirstFactor(strategy: .resetPasswordPhoneCode(code: code))
      default:
        return
      }

      dismissKeyboard()
      verificationState = .success
      authState.setToStepForStatus(signIn: signIn)
    }

  }

  #Preview("Email Code") {
    let _ = Container.shared.signInService.register {
      var service = SignInService.liveValue
      service.prepareFirstFactor = { _, _ in
        try! await Task.sleep(for: .seconds(1))
        return .mock
      }

      service.attemptFirstFactor = { _, _ in
        try! await Task.sleep(for: .seconds(1))
        return .mock
      }

      return service
    }

    SignInFactorOneCodeView(factor: .mockEmailCode)
      .environment(\.clerk, .mock)
  }

  #Preview("Phone Code") {
    let _ = Container.shared.signInService.register {
      var service = SignInService.liveValue
      service.prepareFirstFactor = { _, _ in
        try! await Task.sleep(for: .seconds(1))
        return .mock
      }

      service.attemptFirstFactor = { _, _ in
        try! await Task.sleep(for: .seconds(1))
        return .mock
      }

      return service
    }

    SignInFactorOneCodeView(factor: .mockPhoneCode)
      .environment(\.clerk, .mock)
  }

  #Preview("Reset Password Email Code") {
    let _ = Container.shared.signInService.register {
      var service = SignInService.liveValue
      service.prepareFirstFactor = { _, _ in
        try! await Task.sleep(for: .seconds(1))
        return .mock
      }

      service.attemptFirstFactor = { _, _ in
        try! await Task.sleep(for: .seconds(1))
        return .mock
      }

      return service
    }

    SignInFactorOneCodeView(factor: .mockResetPasswordEmailCode)
      .environment(\.clerk, .mock)
  }

  #Preview("Reset Password Phone Code") {
    let _ = Container.shared.signInService.register {
      var service = SignInService.liveValue
      service.prepareFirstFactor = { _, _ in
        try! await Task.sleep(for: .seconds(1))
        return .mock
      }

      service.attemptFirstFactor = { _, _ in
        try! await Task.sleep(for: .seconds(1))
        return .mock
      }

      return service
    }

    SignInFactorOneCodeView(factor: .mockResetPasswordPhoneCode)
      .environment(\.clerk, .mock)
  }

#endif
