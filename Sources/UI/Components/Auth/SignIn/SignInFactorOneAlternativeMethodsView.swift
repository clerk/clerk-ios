//
//  SignInFactorOneAlternativeMethodsView.swift
//
//
//  Created by Mike Pitre on 12/21/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import NukeUI

struct SignInFactorOneAlternativeMethodsView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @State private var errorWrapper: ErrorWrapper?
    
    let currentFactor: Factor?
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    private var thirdPartyProviders: [OAuthProvider] {
        clerk.environment.userSettings.enabledThirdPartyProviders.sorted()
    }
    
    private func signIn(provider: OAuthProvider) async {
        do {
            try await signIn.create(.oauth(provider: provider))
            try await signIn.startOAuth()
        } catch {
            clerkUIState.presentedAuthStep = .signInStart
            dump(error)
        }
    }
    
    private func startAlternateFirstFactor(_ factor: Factor) async {
        do {
            switch factor.verificationStrategy {
            case .password:
                clerkUIState.presentedAuthStep = .signInPassword
            default:
                if let prepareStrategy = factor.prepareFirstFactorStrategy {
                    try await signIn.prepareFirstFactor(prepareStrategy)
                    clerkUIState.presentedAuthStep = .signInFactorOne(factor)
                } else {
                    throw ClerkClientError(message: "Unable to start this sign in method.")
                }
            }
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(thirdPartyProviders) { provider in
                AsyncButton {
                    await signIn(provider: provider)
                } label: {
                    HStack {
                        LazyImage(url: provider.iconImageUrl) { state in
                            if let image = state.image {
                                image.resizable().scaledToFit()
                            } else {
                                Color(.secondarySystemBackground)
                            }
                        }
                        .frame(width: 16, height: 16)
                        
                        Text("Continue with \(provider.data.name)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClerkSecondaryButtonStyle())
            }
            
            ForEach(signIn.alternativeFirstFactors(currentStrategy: currentFactor?.verificationStrategy), id: \.self) { factor in
                if let actionText = factor.actionText {
                    AsyncButton {
                        await startAlternateFirstFactor(factor)
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
    SignInFactorOneAlternativeMethodsView(currentFactor: nil)
}

#endif