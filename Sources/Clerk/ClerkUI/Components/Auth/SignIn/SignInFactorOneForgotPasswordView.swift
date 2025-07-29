//
//  SignInFactorOneForgotPasswordView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/7/25.
//

#if os(iOS)

import SwiftUI

struct SignInFactorOneForgotPasswordView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.authState) private var authState

    @State private var error: Error?

    var signIn: SignIn? {
        clerk.client?.signIn
    }

    var alternativeFactors: [Factor] {
        let factors = signIn?.alternativeFirstFactors(currentFactor: nil) ?? []
        return factors.filter({ $0.strategy != "password" })
    }

    var socialProviders: [OAuthProvider] {
        clerk.environment.authenticatableSocialProviders
    }

    func actionText(factor: Factor) -> LocalizedStringKey? {
        switch factor.strategy {
        case "phone_code":
            guard let safeIdentifier = factor.safeIdentifier else { return nil }
            return "Send SMS code to \(safeIdentifier.formattedAsPhoneNumberIfPossible)"
        case "email_code":
            guard let safeIdentifier = factor.safeIdentifier else { return nil }
            return "Email code to \(safeIdentifier)"
        case "passkey":
            return "Sign in with your passkey"
        case "password":
            return "Sign in with your password"
        case "totp":
            return "Use your authenticator app"
        case "backup_code":
            return "Use a backup code"
        default:
            return nil
        }
    }

    func iconName(factor: Factor) -> String? {
        switch factor.strategy {
        case "password":
            return "icon-lock"
        case "phone_code":
            return "icon-sms"
        case "email_code":
            return "icon-email"
        case "passkey":
            return "icon-fingerprint"
        default:
            return nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeaderView(style: .title, text: "Forgot password?")
                    .padding(.bottom, 32)

                VStack(spacing: 16) {
                    AsyncButton {
                        await resetPassword()
                    } label: { isRunning in
                        Text("Reset your password", bundle: .module)
                            .frame(maxWidth: .infinity)
                            .overlayProgressView(isActive: isRunning) {
                                SpinnerView(color: theme.colors.textOnPrimaryBackground)
                            }
                    }
                    .buttonStyle(.primary())
                    .simultaneousGesture(TapGesture())

                    TextDivider(string: "Or, sign in with another method")

                    SocialButtonLayout {
                        ForEach(socialProviders) { provider in
                            SocialButton(provider: provider) {
                                await signInWithProvider(provider)
                            }
                            .simultaneousGesture(TapGesture())
                        }
                    }

                    ForEach(alternativeFactors, id: \.self) { factor in
                        if let actionText = actionText(factor: factor) {
                            Button {
                                authState.path.append(
                                    AuthView.Destination.signInFactorOne(factor: factor)
                                )
                            } label: {
                                HStack(spacing: 6) {
                                    if let iconName = iconName(factor: factor) {
                                        Image(iconName, bundle: .module)
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                            .scaledToFit()
                                            .foregroundStyle(theme.colors.textSecondary)
                                    }
                                    Text(actionText, bundle: .module)
                                        .font(theme.fonts.body)
                                        .foregroundStyle(theme.colors.text)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.secondary())
                            .simultaneousGesture(TapGesture())
                        }
                    }
                }
                .padding(.bottom, 32)

                SecuredByClerkView()
            }
            .padding(16)
        }
        .clerkErrorPresenting($error)
        .background(theme.colors.background)
    }
}

extension SignInFactorOneForgotPasswordView {

    func resetPassword() async {
        guard let signIn, let resetFactor = signIn.resetPasswordFactor else {
            authState.path = []
            return
        }

        authState.path.append(
            AuthView.Destination.signInFactorOne(factor: resetFactor)
        )
    }

    func signInWithProvider(_ provider: OAuthProvider) async {
        do {
            guard let signIn else {
                authState.path = []
                return
            }

            var result: TransferFlowResult

            if provider == .apple {
                result = try await SignInWithAppleUtils.signIn()
            } else {
                result =
                    try await signIn
                    .prepareFirstFactor(strategy: .oauth(provider: provider))
                    .authenticateWithRedirect()
            }

            switch result {
            case .signIn(let signIn):
                authState.setToStepForStatus(signIn: signIn)
            case .signUp(let signUp):
                authState.setToStepForStatus(signUp: signUp)
            }

        } catch {
            if error.isUserCancelledError { return }
            self.error = error
            ClerkLogger.error("Failed to sign in with OAuth provider in forgot password flow", error: error)
        }
    }

}

#Preview {
    SignInFactorOneForgotPasswordView()
        .environment(\.clerk, .mock)
        .environment(\.clerkTheme, .clerk)
}

#endif
