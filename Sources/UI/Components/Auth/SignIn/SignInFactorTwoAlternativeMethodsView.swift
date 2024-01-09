//
//  SignInFactorTwoAlternativeMethodsView.swift
//
//
//  Created by Mike Pitre on 1/8/24.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import NukeUI

struct SignInFactorTwoAlternativeMethodsView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @State private var errorWrapper: ErrorWrapper?
    
    let currentFactor: Factor?
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    private func startAlternateSecondFactor(_ factor: Factor) async {
        do {
            if let prepareStrategy = factor.prepareSecondFactorStrategy {
                try await signIn.prepareSecondFactor(prepareStrategy)
            }
            clerkUIState.presentedAuthStep = .signInFactorTwo(factor)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(signIn.alternativeSecondFactors(currentStrategy: currentFactor?.verificationStrategy), id: \.self) { factor in
                if let actionText = factor.actionText {
                    AsyncButton {
                        await startAlternateSecondFactor(factor)
                    } label: {
                        HStack {
                            if let icon = factor.verificationStrategy?.icon {
                                Image(systemName: icon)
                                    .frame(width: 16, height: 16)
                            }
                            
                            Text(actionText)
                        }
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
    SignInFactorTwoAlternativeMethodsView(currentFactor: nil)
        .environmentObject(Clerk.mock)
}

#endif
