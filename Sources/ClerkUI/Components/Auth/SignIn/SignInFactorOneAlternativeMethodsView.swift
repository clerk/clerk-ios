//
//  SignInFactorOneAlternativeMethodsView.swift
//
//
//  Created by Mike Pitre on 12/21/23.
//

#if os(iOS)

import SwiftUI
import Clerk
import AuthenticationServices

struct SignInFactorOneAlternativeMethodsView: View {
    private let clerk = Clerk.shared
    @Environment(ClerkUIState.self) private var clerkUIState
    @State private var errorWrapper: ErrorWrapper?
    
    // The alternative sign in methods on the shared signin can change when initiating an oauth sign in
    // this is a reference to the original alternatives to the UI doesnt change unexpectedly
    @State private var initialAlternatives: [SignInFactor] = []
    
    let currentFactor: SignInFactor
    
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
    
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
            if result?.signIn != nil {
                clerkUIState.setAuthStepToCurrentSignInStatus()
            }
        } catch {
            if case ASWebAuthenticationSessionError.canceledLogin = error {
                clerkUIState.presentedAuthStep = .signInStart
            }

            if error.isCancelledError { return }
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func signInWithApple() async throws -> ExternalAuthResult {
        let appleIdCredential = try await SignInWithAppleManager.getAppleIdCredential()
        
        guard let idToken = appleIdCredential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
            throw ClerkClientError(message: "Unable to get ID token from Apple ID Credential.")
        }
        
        return try await SignIn
            .create(strategy: .idToken(provider: .apple, idToken: idToken))
            .authenticateWithIdToken()
    }
    
    private func startAlternateFirstFactor(_ factor: SignInFactor) async {
        do {
            if let prepareStrategy = factor.prepareFirstFactorStrategy {
                try await signIn?.prepareFirstFactor(for: prepareStrategy)
            }
            
            clerkUIState.presentedAuthStep = .signInFactorOne(factor: factor)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    func icon(for strategy: String) -> String? {
        switch strategy {
        case "password":
            return "lock.fill"
        case "phone_code":
            return "text.bubble.fill"
        case "email_code":
            return "envelope.fill"
        case "passkey":
            return "person.badge.key.fill"
        default:
            return nil
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
            
            ForEach(initialAlternatives, id: \.self) { factor in
                if let actionText = factor.actionText {
                    AsyncButton {
                        await startAlternateFirstFactor(factor)
                    } label: {
                        HStack {
                            if let icon = icon(for: factor.strategy) {
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
        .task {
            initialAlternatives = signIn?.alternativeFirstFactors(currentFactor: currentFactor) ?? []
        }
    }
}

#Preview {
    SignInFactorOneAlternativeMethodsView(currentFactor: .mock)
        .padding()
        .environment(AuthView.Config())
        .environment(ClerkUIState())
        .environment(ClerkTheme.clerkDefault)
}

#endif
