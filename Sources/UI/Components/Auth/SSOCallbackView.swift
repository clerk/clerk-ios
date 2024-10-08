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
    @State private var showCaptcha = false
    @State private var captchaToken: String?
    
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
    
    var body: some View {
        ZStack {
            ProgressView("Verifying...")
            TurnstileWebView(widgetType: .invisible)
                .onSuccess { token in
                    captchaToken = token
                }
                .onDidFinishLoading {
                    showCaptcha = true
                }
                .onError { errorMessage in
                    errorWrapper = ErrorWrapper(error: ClerkClientError(message: errorMessage))
                    dump(errorMessage)
                }
                .frame(width: 300, height: 65)
                .scaleEffect(showCaptcha ? 1 : 0)
                .animation(.bouncy.speed(1.5), value: showCaptcha)
        }
        .clerkErrorPresenting($errorWrapper)
        .task(id: captchaToken) {
            guard let captchaToken else { return }
            do {
                try await handleTransferFlow(token: captchaToken)
            } catch {
                errorWrapper = ErrorWrapper(error: error)
            }
        }
    }
    
    private func handleTransferFlow(token: String) async throws {
        guard signIn?.needsTransferToSignUp == true else {
            clerkUIState.presentedAuthStep = .signInStart
            return
        }
        
        try await SignUp.create(strategy: .transfer, captchaToken: token)
        clerkUIState.setAuthStepToCurrentSignUpStatus()
    }
    
}

#Preview {
    SSOCallbackView()
}

#endif
