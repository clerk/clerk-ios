//
//  SignInFactorTwoAlternativeMethodsView.swift
//
//
//  Created by Mike Pitre on 1/8/24.
//

#if os(iOS)

import SwiftUI
import Clerk

struct SignInFactorTwoAlternativeMethodsView: View {
    var clerk = Clerk.shared
    @Environment(ClerkUIState.self) private var clerkUIState
    @State private var errorWrapper: ErrorWrapper?
    
    let currentFactor: SignInFactor
    
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
            
    private func startAlternateSecondFactor(_ factor: SignInFactor) async {
        do {
            if let prepareStrategy = factor.prepareSecondFactorStrategy {
                try await signIn?.prepareSecondFactor(for: prepareStrategy)
            }
            
            clerkUIState.setAuthStepToCurrentSignInStatus()
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
            ForEach(signIn?.alternativeSecondFactors(currentFactor: currentFactor) ?? [], id: \.self) { factor in
                if let actionText = factor.actionText {
                    AsyncButton {
                        await startAlternateSecondFactor(factor)
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
    }
}

#Preview {
    SignInFactorTwoAlternativeMethodsView(currentFactor: .mock)
}

#endif
