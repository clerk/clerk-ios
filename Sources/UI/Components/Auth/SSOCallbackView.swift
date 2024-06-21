//
//  SSOCallbackView.swift
//
//
//  Created by Mike Pitre on 6/21/24.
//

#if os(iOS)

import SwiftUI

struct SSOCallbackView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @State private var errorWrapper: ErrorWrapper?
    @State private var captchaToken: String?
    @State private var captchaIsInteractive = false
    
    var body: some View {
        ZStack {
            ProgressView("Verifying your identity...")
            TurnstileWebView(appearence: .always)
                .onSuccess { token in
                    captchaToken = token
                }
                .onFinishLoading {
                    captchaIsInteractive = true
                }
                .onError { errorMessage in
                    errorWrapper = ErrorWrapper(error: ClerkClientError(message: errorMessage))
                    dump(errorMessage)
                }
                .frame(width: 300, height: 65)
                .scaleEffect(captchaIsInteractive ? 1 : 0)
                .animation(.bouncy.speed(1.5), value: captchaIsInteractive)
        }
        .clerkErrorPresenting($errorWrapper)
        .task(id: captchaToken) {
            guard let captchaToken else { return }
            do {
                try await handleSSOCallback(token: captchaToken)
            } catch {
                errorWrapper = ErrorWrapper(error: error)
            }
        }
    }
    
    private func handleSSOCallback(token: String) async throws {
        guard
            let signIn = clerk.client?.signIn,
            signIn.firstFactorVerification?.status == .transferable ||
            signIn.secondFactorVerification?.status == .transferable
        else {
            clerkUIState.presentedAuthStep = .signInStart
            return
        }
        
        let signUp = try await SignUp.create(strategy: .transfer, captchaToken: token)
        clerkUIState.setAuthStepToCurrentStatus(for: signUp)
    }
    
    
}

#Preview {
    SSOCallbackView()
}

#endif
