//
//  SignUpCodeView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/20/25.
//

#if os(iOS)

  import SwiftUI

  struct SignUpCodeView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.authState) private var authState

    @State private var code = ""
    @State private var remainingSeconds: Int = 30
    @State private var timer: Timer?
    @State private var verificationState = VerificationState.default
    @State private var error: Error?

    @FocusState private var otpFieldIsFocused: Bool

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
        case .email(let emailAddress):
          emailAddress
        case .phone(let phoneNumber):
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

    let field: Field

    var body: some View {
      ScrollView {
        VStack(spacing: 32) {
          VStack(spacing: 8) {
            HeaderView(style: .title, text: field.title)
            Button {
              authState.path = []
            } label: {
              IdentityPreviewView(label: field.identityPreviewString)
            }
            .buttonStyle(.secondary(config: .init(size: .small)))
            .simultaneousGesture(TapGesture())
          }

          VStack(spacing: 24) {
            OTPField(code: $code, isFocused: $otpFieldIsFocused) { code in
              do {
                try await attempt()
                return .default
              } catch {
                verificationState = .error(error)
                return .error
              }
            }
            .onFirstAppear {
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
          }

          SecuredByClerkView()
        }
        .padding(16)
      }
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Sign up", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.text)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .background(theme.colors.background)
      .clerkErrorPresenting($error)
      .taskOnce {
        startTimer()
        if authState.lastCodeSentAt[field.identityPreviewString] == nil {
          await prepare()
        }
      }
    }
  }

  extension SignUpCodeView {

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
      guard let lastCodeSentAt = authState.lastCodeSentAt[field.identityPreviewString] else {
        return
      }

      let elapsed = Int(Date.now.timeIntervalSince(lastCodeSentAt))
      remainingSeconds = max(0, 30 - elapsed)
    }

    func prepare() async {
      code = ""
      verificationState = .default

      guard var signUp else {
        authState.path = []
        return
      }

      do {
        switch field {
        case .email:
          signUp = try await signUp.prepareVerification(strategy: .emailCode)
        case .phone:
          signUp = try await signUp.prepareVerification(strategy: .phoneCode)
        }

        authState.lastCodeSentAt[field.identityPreviewString] = .now
        updateRemainingSeconds()
      } catch {
        otpFieldIsFocused = false
        self.error = error
      }
    }

    func attempt() async throws {
      guard var signUp else {
        authState.path = []
        return
      }

      verificationState = .verifying

      switch field {
      case .email:
        signUp = try await signUp.attemptVerification(strategy: .emailCode(code: code))
      case .phone:
        signUp = try await signUp.attemptVerification(strategy: .phoneCode(code: code))
      }

      otpFieldIsFocused = false
      verificationState = .success
      authState.setToStepForStatus(signUp: signUp)
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
