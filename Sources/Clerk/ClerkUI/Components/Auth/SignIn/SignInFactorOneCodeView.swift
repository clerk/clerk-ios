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

    @State private var code = ""
    @State private var error: Error?
    @State private var isLoading = false
    @FocusState private var isFocused: Bool

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
            OTPField(code: $code)
              .onCodeEntry {
                Task {
                  await attempt()
                }
              }

            AsyncButton {
              await prepare()
            } label: { isRunning in
              HStack(spacing: 0) {
                Text("Didn't recieve a code? Resend", bundle: .module)
                if remainingSeconds > 0 {
                  Text(" (\(remainingSeconds))")
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: remainingSeconds)
                }
              }
              .font(theme.fonts.subheadline)
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
        if authState.lastCodeSentAt[factor] == nil || remainingSeconds == 0 {
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
      if elapsed >= 30 { authState.lastCodeSentAt[factor] = nil }
      remainingSeconds = max(0, 30 - elapsed)
    }

    func prepare() async {
      isFocused = false
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

    func attempt() async {
      guard let signIn else {
        authState.path = NavigationPath()
        return
      }

      do {
        switch factor.strategy {
        case "email_code":
          try await signIn.attemptFirstFactor(strategy: .emailCode(code: code))
        case "phone_code":
          try await signIn.attemptFirstFactor(strategy: .phoneCode(code: code))
        default:
          return
        }
      } catch {
        self.error = error
      }
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
