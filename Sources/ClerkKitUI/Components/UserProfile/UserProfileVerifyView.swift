//
//  UserProfileVerifyView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/16/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct UserProfileVerifyView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(UserProfileView.SharedState.self) private var sharedState
    @Environment(\.dismiss) private var environmentDismiss

    @State private var code = ""
    @State private var error: Error?
    @State private var remainingSeconds: Int = 30
    @State private var timer: Timer?
    @State private var verificationState = VerificationState.default
    @State private var otpFieldState = OTPField.FieldState.default

    @FocusState private var otpFieldIsFocused: Bool

    var user: User? { clerk.user }

    @State var mode: Mode
    let onCompletion: (_ backupCodes: [String]?) -> Void
    let customDismiss: (() -> Void)?

    enum Mode {
        case email(EmailAddress)
        case phone(PhoneNumber)
        case totp
    }

    private var titleKey: LocalizedStringKey {
        switch mode {
        case .email:
            "Verify email address"
        case .phone:
            "Verify phone number"
        case .totp:
            "Verify authenticator app"
        }
    }

    private var instructionsText: Text {
        switch mode {
        case .email(let emailAddress):
            Text("Enter the verification code sent to \(emailAddress.emailAddress)", bundle: .module)
        case .phone(let phoneNumber):
            Text("Enter the verification code sent to \(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible)", bundle: .module)
        case .totp:
            Text("Enter the verification code from your authenticator application.", bundle: .module)
        }
    }

    private func dismiss() {
        if let customDismiss {
            customDismiss()
        } else {
            environmentDismiss()
        }
    }

    private var hasCancelAction: Bool {
        switch mode {
        case .email, .phone:
            true
        case .totp:
            false
        }
    }

    private var lastCodeSentAtKey: String {
        switch mode {
        case .email(let emailAddress):
            return emailAddress.emailAddress
        case .phone(let phoneNumber):
            return phoneNumber.phoneNumber
        case .totp:
            return ""
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

    var showResend: Bool {
        switch mode {
        case .email, .phone:
            true
        case .totp:
            false
        }
    }

    var resendString: LocalizedStringKey {
        if remainingSeconds > 0 {
            "Resend (\(remainingSeconds))"
        } else {
            "Resend"
        }
    }

    init(
        mode: Mode,
        onCompletion: @escaping (_ backupCodes: [String]?) -> Void,
        customDismiss: (() -> Void)? = nil
    ) {
        self._mode = .init(initialValue: mode)
        self.onCompletion = onCompletion
        self.customDismiss = customDismiss
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                instructionsText
                    .font(theme.fonts.subheadline)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                OTPField(
                    code: $code,
                    fieldState: $otpFieldState,
                    isFocused: $otpFieldIsFocused
                ) { code in
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

                if showResend {
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
            .padding(24)
        }
        .clerkErrorPresenting($error)
        .presentationBackground(theme.colors.background)
        .background(theme.colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .preGlassSolidNavBar()
        .navigationBarBackButtonHidden(hasCancelAction)
        .toolbar {
            if hasCancelAction {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(theme.colors.primary)
                }
            }

            ToolbarItem(placement: .principal) {
                Text(titleKey, bundle: .module)
                    .font(theme.fonts.headline)
                    .foregroundStyle(theme.colors.foreground)
            }
        }
        .taskOnce {
            if showResend {
                startTimer()
                if sharedState.lastCodeSentAt[lastCodeSentAtKey] == nil {
                    await prepare()
                }
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
            case .totp:
                return
            }

            sharedState.lastCodeSentAt[lastCodeSentAtKey] = .now
            updateRemainingSeconds()
        } catch {
            otpFieldIsFocused = false
            self.error = error
            ClerkLogger.error("Failed to prepare verification", error: error)
        }
    }

    func attempt() async {
        verificationState = .verifying

        do {
            switch mode {
            case .email(let emailAddress):
                try await emailAddress.attemptVerification(strategy: .emailCode(code: code))
                sharedState.lastCodeSentAt[emailAddress.emailAddress] = nil
                verificationState = .success
                onCompletion(nil)
            case .phone(let phoneNumber):
                try await phoneNumber.attemptVerification(code: code)
                sharedState.lastCodeSentAt[phoneNumber.phoneNumber] = nil
                verificationState = .success
                onCompletion(nil)
            case .totp:
                guard let user else { return }
                let totp = try await user.verifyTOTP(code: code)
                verificationState = .success
                onCompletion(totp.backupCodes)
            }
        } catch {
            otpFieldState = .error
            verificationState = .error(error)

            if let clerkError = error as? ClerkAPIError, clerkError.meta?["param_name"] == nil {
                self.error = clerkError
                otpFieldIsFocused = false
            }
        }
    }

}

#Preview("Email") {
    NavigationStack {
        UserProfileVerifyView(mode: .email(.mock)) { _ in }
    }
    .environment(\.clerkTheme, .clerk)
}

#Preview("Phone") {
    NavigationStack {
        UserProfileVerifyView(mode: .phone(.mock)) { _ in }
    }
    .environment(\.clerkTheme, .clerk)
}

#endif
