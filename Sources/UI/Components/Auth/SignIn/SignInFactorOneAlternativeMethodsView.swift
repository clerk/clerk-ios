//
//  SignInFactorOneAlternativeMethodsView.swift
//
//
//  Created by Mike Pitre on 12/21/23.
//

#if os(iOS)

import SwiftUI
import NukeUI

struct SignInFactorOneAlternativeMethodsView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @State private var errorWrapper: ErrorWrapper?
    
    let signIn: SignIn
    let currentFactor: SignInFactor?
    
    private var socialProviders: [OAuthProvider] {
        (clerk.environment?.userSettings.authenticatableSocialProviders ?? []).sorted()
    }
    
    private func signIn(provider: OAuthProvider) async {
        do {
            var result: ExternalAuthResult?
            
            if provider == .apple {
                result = try await signInWithApple()
            } else {
                result = try await SignIn
                    .create(strategy: .oauth(provider))
                    .authenticateWithRedirect()
            }
            
            // if the user didnt cancel
            if let signIn = result?.signIn {
                clerkUIState.setAuthStepToCurrentStatus(for: signIn)
            }
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func signInWithApple() async throws -> ExternalAuthResult? {
        guard let appleIdCredential = try await ExternalAuthUtils.getAppleIdCredential() else {
            return nil
        }
        
        guard let token = appleIdCredential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
            throw ClerkClientError(message: "Unable to get ID token from Apple ID Credential.")
        }
        
        return try await SignIn.signInWithAppleIdToken(
            idToken: token
        )
    }
    
    private func startAlternateFirstFactor(_ factor: SignInFactor) async {
        do {
            var signIn = signIn
            
            if let prepareStrategy = factor.prepareFirstFactorStrategy {
                signIn = try await signIn.prepareFirstFactor(for: prepareStrategy)
            }
            clerkUIState.presentedAuthStep = .signInFactorOne(signIn: signIn, factor: factor)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(socialProviders) { provider in
                AsyncButton {
                    await signIn(provider: provider)
                } label: {
                    HStack {
                        AuthProviderIcon(provider: provider)
                            .frame(width: 16, height: 16)
                        
                        Text("Continue with \(provider.name)")
                    }
                    .clerkStandardButtonPadding()
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClerkSecondaryButtonStyle())
            }
            
            ForEach(signIn.alternativeFirstFactors(currentFactor: currentFactor) ?? [], id: \.self) { factor in
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
    SignInFactorOneAlternativeMethodsView(signIn: .mock, currentFactor: nil)
        .padding()
}

#endif
