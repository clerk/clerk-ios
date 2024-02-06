//
//  SignInFactorOneAlternativeMethodsView.swift
//
//
//  Created by Mike Pitre on 12/21/23.
//

#if canImport(UIKit)

import SwiftUI
import ClerkSDK
import NukeUI

struct SignInFactorOneAlternativeMethodsView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @State private var errorWrapper: ErrorWrapper?
    
    let currentFactor: Factor?
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    private var thirdPartyProviders: [ExternalProvider] {
        clerk.environment.userSettings.enabledThirdPartyProviders.sorted()
    }
    
    private func signIn(provider: ExternalProvider) async {
        do {
            try await signIn.create(.externalProvider(provider))
            try await signIn.startExternalAuth()
            clerkUIState.setAuthStepToCurrentStatus(for: signIn)
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
            clerkUIState.presentedAuthStep = .signInFactorOne(factor)
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
                    .clerkStandardButtonPadding()
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
    SignInFactorOneAlternativeMethodsView(currentFactor: nil)
        .padding()
        .environmentObject(Clerk.mock)
}

#endif
