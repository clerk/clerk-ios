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
    @State private var otpFieldState = OTPField.FieldState.default
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

    private func lastCodeSentAtKey(_ signUp: SignUp) -> String {
        signUp.id + field.identityPreviewString
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
                    OTPField(code: $code, fieldState: $otpFieldState, isFocused: $otpFieldIsFocused) { code in
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
                        authState.setToStepForStatus(signUp: signUp)
                    }
                }
                return nil
            }
        )
        .taskOnce {
            startTimer()
            if let signUp, authState.lastCodeSentAt[lastCodeSentAtKey(signUp)] == nil {
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
        guard let signUp, let lastCodeSentAt = authState.lastCodeSentAt[lastCodeSentAtKey(signUp)] else {
            return
        }

        let elapsed = Int(Date.now.timeIntervalSince(lastCodeSentAt))
        remainingSeconds = max(0, 30 - elapsed)
    }

    func prepare() async {
        code = ""
        otpFieldState = .default
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

            authState.lastCodeSentAt[lastCodeSentAtKey(signUp)] = .now
            updateRemainingSeconds()
        } catch {
            otpFieldIsFocused = false
            self.error = error
            ClerkLogger.error("Failed to prepare verification for sign up", error: error)
        }
    }

    func attempt() async {
        guard var signUp else {
            authState.path = []
            return
        }

        otpFieldState = .default
        verificationState = .verifying

        do {
            switch field {
            case .email:
                signUp = try await signUp.attemptVerification(strategy: .emailCode(code: code))
            case .phone:
                signUp = try await signUp.attemptVerification(strategy: .phoneCode(code: code))
            }

            otpFieldIsFocused = false
            verificationState = .success
            authState.setToStepForStatus(signUp: signUp)
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
