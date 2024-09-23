//
//  SignInFactorOnePasskeyView.swift
//  Clerk
//
//  Created by Mike Pitre on 9/12/24.
//

#if os(iOS)

import SwiftUI
import AuthenticationServices

struct SignInFactorOnePasskeyView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var errorWrapper: ErrorWrapper?
    
    let signIn: SignIn
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                VStack {
                    Image(systemName: "person.badge.key.fill")
                        .imageScale(.large)
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(.rect(cornerRadius: 8, style: .continuous))
                    
                    HeaderView(
                        title: "Use your passkey",
                        subtitle: "Using your passkey confirm's its you. Your device may ask for your fingerprint, face or pin code."
                    )
                    .multilineTextAlignment(.center)
                    
                    if let identifier = signIn.currentFirstFactor?.safeIdentifier ?? signIn.identifier {
                        IdentityPreviewView(
                            label: identifier,
                            action: {
                                clerkUIState.presentedAuthStep = .signInStart
                            }
                        )
                    }
                    
                    AsyncButton(action: signInWithPasskey) {
                        Text("Continue")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkPrimaryButtonStyle())
                    .padding(.top, 32)
                    .padding(.bottom, 18)
                    
                    AsyncButton {
                        clerkUIState.presentedAuthStep = .signInFactorOneUseAnotherMethod(
                            signIn: signIn,
                            currentFactor: signIn.firstFactor(for: .passkey)
                        )
                    } label: {
                        Text("Use another method")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.textSecondary)
                    }
                }
                
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
        }
        .clerkErrorPresenting($errorWrapper)
    }
}

extension SignInFactorOnePasskeyView {
    
    private func signInWithPasskey() async {
        do {
            let preparedSignIn = try await signIn
                .prepareFirstFactor(for: .passkey)
            
            let credential = try await preparedSignIn
                .getCredentialForPasskey()
            
            let attemptedSignIn = try await preparedSignIn.attemptFirstFactor(
                for: .passkey(publicKeyCredential: credential)
            )
            
            clerkUIState.setAuthStepToCurrentStatus(for: attemptedSignIn)
        } catch {
            if error.isCancelledError { return }
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
}

#Preview {
    SignInFactorOnePasskeyView(signIn: .mock)
        .environmentObject(ClerkUIState())
}

#endif
