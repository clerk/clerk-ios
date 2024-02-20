//
//  SignInFactorOneEmailLinkView.swift
//
//
//  Created by Mike Pitre on 2/20/24.
//

import SwiftUI

struct SignInFactorOneEmailLinkView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @State private var errorWrapper: ErrorWrapper?
        
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .padding(.bottom, 24)
                
                VStack(spacing: 4) {
                    HeaderView(
                        title: "Check your email",
                        subtitle: "Use the verification link sent to your email"
                    )
                    .multilineTextAlignment(.center)
                    
                    IdentityPreviewView(
                        label: signIn.currentFirstFactor?.safeIdentifier ?? signIn.identifier,
                        action: {
                            clerkUIState.presentedAuthStep = .signInStart
                        }
                    )
                }
                .padding(.bottom, 32)
                
                Button {
                    clerkUIState.presentedAuthStep = .signInFactorOneUseAnotherMethod(signIn.firstFactor(for: .emailLink))
                } label: {
                    Text("Use another method")
                        .frame(maxWidth: .infinity)
                        .clerkStandardButtonPadding()
                }
                .buttonStyle(ClerkPrimaryButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
        }
        .clerkErrorPresenting($errorWrapper)
        .task {
            repeat {
                do {
                    try await signIn.get()
                    clerkUIState.setAuthStepToCurrentStatus(for: signIn)
                    try? await Task.sleep(for: .seconds(1))
                } catch {
                    errorWrapper = ErrorWrapper(error: error)
                    dump(error)
                }
            } while (!Task.isCancelled)
        }
    }
}

#Preview {
    SignInFactorOneEmailLinkView()
        .environmentObject(Clerk.shared)
}
