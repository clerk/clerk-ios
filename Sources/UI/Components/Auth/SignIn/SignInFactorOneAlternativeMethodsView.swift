//
//  SignInFactorOneAlternativeMethodsView.swift
//
//
//  Created by Mike Pitre on 12/21/23.
//

#if os(iOS)

import SwiftUI
import NukeUI
import AuthenticationServices

struct SignInFactorOneAlternativeMethodsView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @State private var errorWrapper: ErrorWrapper?
    
    let currentFactor: SignInFactor?
    
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
    
    private var oauthProviders: [OAuthProvider] {
        (clerk.environment?.userSettings.enabledOAuthProviders ?? []).sorted()
    }
    
    private func signIn(provider: OAuthProvider) async {
        do {
            if provider == .apple {
                try await signInWithApple()
            } else {
                try await SignIn
                    .create(strategy: .oauth(provider))
                    .authenticateWithRedirect()
            }
            
            clerkUIState.setAuthStepToCurrentStatus(for: signIn)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
			clerkUIState.presentedAuthStep = .signInStart
            dump(error)
        }
    }
    
    private func signInWithApple() async throws {
        guard let appleIdCredential = try await OAuthUtils.getAppleIdCredential() else {
            return
        }
        
        guard let token = appleIdCredential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
            throw ClerkClientError(message: "Unable to get ID token from Apple ID Credential.")
        }
                        
        let authCode = appleIdCredential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) })
        
        try await SignIn.signInWithAppleIdToken(idToken: token, code: authCode)
    }
    
    private func startAlternateFirstFactor(_ factor: SignInFactor) async {
        do {
            if let prepareStrategy = factor.prepareFirstFactorStrategy {
                try await signIn?.prepareFirstFactor(for: prepareStrategy)
            }
            clerkUIState.presentedAuthStep = .signInFactorOne(factor)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(oauthProviders) { provider in
                AsyncButton {
                    await signIn(provider: provider)
                } label: {
                    HStack {
                        AuthProviderIcon(provider: provider)
                            .frame(width: 16, height: 16)
                        
                        Text("Continue with \(provider.providerData.name)")
                    }
                    .clerkStandardButtonPadding()
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClerkSecondaryButtonStyle())
            }
            
            ForEach(signIn?.alternativeFirstFactors(currentFactor: currentFactor) ?? [], id: \.self) { factor in
                if let actionText = factor.actionText {
                    AsyncButton {
                        await startAlternateFirstFactor(factor)
                    } label: {
                        HStack {
                            if let icon = factor.strategyEnum?.icon {
                                Image(systemName: icon)
                                    .frame(width: 16, height: 16)
                            }
                            
                            Text(actionText)
                        }
                        .clerkStandardButtonPadding()
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkSecondaryButtonStyle())
                }
            }
        }
        .clerkErrorPresenting($errorWrapper)
    }
}

#Preview {
    SignInFactorOneAlternativeMethodsView(currentFactor: nil)
        .padding()
}

#endif
