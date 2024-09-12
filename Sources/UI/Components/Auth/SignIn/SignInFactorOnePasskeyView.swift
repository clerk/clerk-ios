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
    
    var signIn: SignIn? {
        clerk.client?.signIn
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 48)
                
                VStack {
                    Image(systemName: "person.badge.key.fill")
                        .resizable()
                        .scaledToFit()
                        .imageScale(.large)
                        .frame(width: 40, height: 40)
                        .offset(x: 7)
                    
                    HeaderView(
                        title: "Use your passkey",
                        subtitle: "Using your passkey confirm's its you. Your device may ask for your fingerprint, face or pin code."
                    )
                    .multilineTextAlignment(.center)
                    
                    if let identifier = signIn?.currentFirstFactor?.safeIdentifier ?? signIn?.identifier {
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
                        clerkUIState.presentedAuthStep = .signInFactorOneUseAnotherMethod(signIn?.firstFactor(for: .passkey))
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
            guard let signIn else {
                throw ClerkClientError(message: "Something went wrong. Please use another method.")
                return
            }
            
            let attemptedSignIn = try await signIn
                .prepareFirstFactor(for: .passkey)
                .authenticateWithPasskey()
            
            clerkUIState.setAuthStepToCurrentStatus(for: attemptedSignIn)
        } catch {
            if case ASAuthorizationError.canceled = error {
                // user cancelled
            } else {
                errorWrapper = ErrorWrapper(error: error)
                dump(error)
            }
        }
    }
    
}

#Preview {
    SignInFactorOnePasskeyView()
        .environmentObject(ClerkUIState())
}

#endif
