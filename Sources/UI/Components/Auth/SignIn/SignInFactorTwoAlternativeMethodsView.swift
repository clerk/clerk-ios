//
//  SignInFactorTwoAlternativeMethodsView.swift
//
//
//  Created by Mike Pitre on 1/8/24.
//

#if os(iOS)

import SwiftUI
import NukeUI

struct SignInFactorTwoAlternativeMethodsView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @State private var errorWrapper: ErrorWrapper?
    
    let signIn: SignIn
    let currentFactor: SignInFactor?
    
    private func startAlternateSecondFactor(_ factor: SignInFactor) async {
        do {
            var signIn = signIn
            
            if let prepareStrategy = factor.prepareSecondFactorStrategy {
                signIn = try await signIn.prepareSecondFactor(for: prepareStrategy)
            }
            
            clerkUIState.setAuthStepToCurrentStatus(for: signIn)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(signIn.alternativeSecondFactors(currentFactor: currentFactor) ?? [], id: \.self) { factor in
                if let actionText = factor.actionText {
                    AsyncButton {
                        await startAlternateSecondFactor(factor)
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
    SignInFactorTwoAlternativeMethodsView(signIn: .mock, currentFactor: nil)
}

#endif
