//
//  SignUpCreatePasskeyView.swift
//  Clerk
//
//  Created by Mike Pitre on 9/13/24.
//

#if os(iOS)

import SwiftUI
import AuthenticationServices

struct SignUpCreatePasskeyView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(ClerkTheme.self) private var clerkTheme
    @Environment(ClerkUIState.self) private var clerkUIState
    @State private var errorWrapper: ErrorWrapper?
    
    private var signUp: SignUp? {
        clerk.client?.signUp
    }
    
    private var user: User? {
        clerk.user
    }
        
    var body: some View {
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
                    title: "Create a Passkey",
                    subtitle: "Saving and using a passkey is quick and easy with one-step sign-in using Face ID or Touch ID. Because passkeys are synced with iCloud Keychain, they’re available across Apple devices."
                )
                .multilineTextAlignment(.center)
                
                AsyncButton(action: createPasskey) {
                    Text("Continue")
                        .clerkStandardButtonPadding()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClerkPrimaryButtonStyle())
                .padding(.top, 32)
                .padding(.bottom, 18)
                
                AsyncButton {
                    clerkUIState.authIsPresented = false
                } label: {
                    Text("Maybe later")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 32)
        .clerkErrorPresenting($errorWrapper)
    }
}

extension SignUpCreatePasskeyView {
    
    private func createPasskey() async {
        do {
            try await user?.createPasskey()
            // we've added a passkey to the users account, so pass the signup back through the UI flow
            clerkUIState.setAuthStepToCurrentSignUpStatus()
        } catch {
            if error.isCancelledError { return }
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
}

#Preview {
    SignUpCreatePasskeyView()
        .environment(ClerkUIState())
}

#endif
