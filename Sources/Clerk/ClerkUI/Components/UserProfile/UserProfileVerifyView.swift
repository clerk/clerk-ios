//
//  UserProfileVerifyView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/16/25.
//

#if os(iOS)

  import SwiftUI

  struct UserProfileVerifyView: View {
    @Environment(\.clerkTheme) private var theme
    @Environment(\.userProfileSharedState) private var sharedState

    @State var mode: Mode
    @State private var code = ""
    @State private var error: Error?
    @State private var fieldError: Error?

    @State private var remainingSeconds: Int = 30
    @State private var timer: Timer?
    @State private var verificationState = VerificationState.default

    @FocusState private var otpFieldIsFocused: Bool
    
    let dismiss: () -> Void

    enum Mode {
      case email(EmailAddress)
      case phone(PhoneNumber)
    }

    private var titleKey: LocalizedStringKey {
      switch mode {
      case .email:
        "Verify email address"
      case .phone:
        "Verify phone number"
      }
    }

    private var instructionsText: Text {
      switch mode {
      case .email(let emailAddress):
        Text("Enter the verification code sent to \(emailAddress.emailAddress)", bundle: .module)
      case .phone(let phoneNumber):
        Text("Enter the verification code sent to \(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible)", bundle: .module)
      }
    }

    private var lastCodeSentAtKey: String {
      switch mode {
      case .email(let emailAddress):
        return emailAddress.emailAddress
      case .phone(let phoneNumber):
        return phoneNumber.phoneNumber
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

    var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          instructionsText
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
          
          OTPField(
            code: $code,
            isFocused: $otpFieldIsFocused
          ) { code in
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
        .padding(24)
      }
      .clerkErrorPresenting($error)
      .background(theme.colors.background)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarBackground(theme.colors.background, for: .navigationBar)
      .navigationBarBackButtonHidden()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundStyle(theme.colors.primary)
        }
        
        ToolbarItem(placement: .principal) {
          Text(titleKey, bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.text)
        }
      }
      .taskOnce {
        startTimer()
        if sharedState.lastCodeSentAt[lastCodeSentAtKey] == nil {
          await prepare()
        }
      }
    }
  }

  extension UserProfileVerifyView {

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
      guard let lastCodeSentAt = sharedState.lastCodeSentAt[lastCodeSentAtKey] else {
        return
      }

      let elapsed = Int(Date.now.timeIntervalSince(lastCodeSentAt))
      remainingSeconds = max(0, 30 - elapsed)
    }

    func prepare() async {
      code = ""
      verificationState = .default

      do {
        switch mode {
        case .email(let emailAddress):
          try await emailAddress.prepareVerification(strategy: .emailCode)
        case .phone(let phoneNumber):
          try await phoneNumber.prepareVerification()
        }

        sharedState.lastCodeSentAt[lastCodeSentAtKey] = .now
        updateRemainingSeconds()
      } catch {
        otpFieldIsFocused = false
        self.error = error
      }
    }

    func attempt() async throws {
      verificationState = .verifying

      switch mode {
      case .email(let emailAddress):
        try await emailAddress.attemptVerification(strategy: .emailCode(code: code))
      case .phone(let phoneNumber):
        try await phoneNumber.attemptVerification(code: code)
      }

      verificationState = .success
      dismiss()
    }

  }

  #Preview("Email") {
    NavigationStack {
      UserProfileVerifyView(mode: .email(.mock)) {}
    }
    .environment(\.clerkTheme, .clerk)
  }

  #Preview("Phone") {
    NavigationStack {
      UserProfileVerifyView(mode: .phone(.mock)) {}
    }
    .environment(\.clerkTheme, .clerk)
  }

#endif
