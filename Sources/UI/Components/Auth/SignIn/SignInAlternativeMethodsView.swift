//
//  SignInAlternativeMethodsView.swift
//
//
//  Created by Mike Pitre on 12/21/23.
//

import SwiftUI
import Clerk
import NukeUI

struct SignInAlternativeMethodsView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @State private var errorWrapper: ErrorWrapper?
    
    let currentStrategy: Strategy?
    
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
            if let prepareStrategy = factor.prepareFirstFactorStrategy {
                try await signIn.prepareFirstFactor(prepareStrategy)
            }
            
            clerkUIState.presentedAuthStep = .signInFactorOneVerify
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
            
            ForEach(signIn.alternativeFirstFactors(currentStrategy: currentStrategy), id: \.self) { factor in
                if let actionText = factor.actionText {
                    AsyncButton {
                        await startAlternateFirstFactor(factor)
                    } label: {
                        HStack {
                            Image(systemName: factor.verificationStrategy?.icon ?? "")
                                .frame(width: 16, height: 16)
                            
                            Text(actionText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkSecondaryButtonStyle())
                }
            }
        }
    }
}

#Preview {
    SignInAlternativeMethodsView(currentStrategy: .password)
}
