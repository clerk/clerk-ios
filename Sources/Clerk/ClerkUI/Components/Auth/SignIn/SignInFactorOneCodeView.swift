//
//  SignInFactorOneCodeView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

#if canImport(SwiftUI)

  import SwiftUI

  struct SignInFactorOneCodeView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.authState) private var authState
    @Environment(\.dismissKeyboard) private var dismissKeyboard

    @State private var code = ""
    @State private var error: Error?
    @State private var isLoading = false
    @State private var remainingSeconds: Int = 30
    @State private var timer: Timer?

    var signIn: SignIn? {
      clerk.client?.signIn
    }

    let factor: Factor

    var title: LocalizedStringKey {
      switch factor.strategy {
      case "email_code":
        "Check your email"
      case "phone_code":
        "Check your phone"
      default:
        ""
      }
    }

    var subtitleString: LocalizedStringKey {
      if let appName = clerk.environment.displayConfig?.applicationName {
        return "to continue to \(appName)"
      } else {
        return "to continue"
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
                IdentityPreviewView(label: identifier)
              }
              .buttonStyle(.secondary(config: .init(size: .small)))
            }
          }
          .padding(.bottom, 32)

          VStack(spacing: 24) {
            OTPField(code: $code) { code in
              do {
                try await attempt()
                return .default
              } catch {
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
              .font(theme.fonts.subheadline)
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

            Button {
              authState.path.append(
                AuthState.Destination.signInFactorOneUseAnotherMethod(
                  currentFactor: factor
                )
              )
            } label: {
              Text("Use another method", bundle: .module)
                .font(theme.fonts.subheadline)
            }
            .buttonStyle(
              .primary(
                config: .init(
                  emphasis: .none,
                  size: .small
                )
              )
            )
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
        updateRemainingSeconds()
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
      isLoading = true
      defer { isLoading = false }

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
        default:
          return
        }

        authState.lastCodeSentAt[factor] = .now
        updateRemainingSeconds()
      } catch {
        self.error = error
      }
    }

    func attempt() async throws {
      guard let signIn else {
        authState.path = NavigationPath()
        return
      }

      switch factor.strategy {
      case "email_code":
        try await signIn.attemptFirstFactor(strategy: .emailCode(code: code))
      case "phone_code":
        try await signIn.attemptFirstFactor(strategy: .phoneCode(code: code))
      default:
        return
      }
      
      dismissKeyboard()
    }

  }

  #Preview("Email Code") {
    SignInFactorOneCodeView(factor: .mockEmailCode)
      .environment(\.clerk, .mock)
  }

  #Preview("Phone Code") {
    SignInFactorOneCodeView(factor: .mockEmailCode)
      .environment(\.clerk, .mock)
  }

#endif
