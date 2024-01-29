//
//  SignUpSocialProvidersView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import AuthenticationServices
import Algorithms

struct SignUpSocialProvidersView: View {
    @EnvironmentObject private var clerk: Clerk
    @State private var errorWrapper: ErrorWrapper?
    @Environment(\.clerkTheme) private var clerkTheme
    
    private var signUp: SignUp {
        clerk.client.signUp
    }
    
    private var thirdPartyProviders: [OAuthProvider] {
        clerk.environment.userSettings.enabledThirdPartyProviders.sorted()
    }
    
    private var chunkedProviders: ChunksOfCountCollection<[OAuthProvider]> {
        thirdPartyProviders.chunks(ofCount: 6)
    }
        
    private var providerButtonMaxWidth: CGFloat {
        chunkedProviders.count > 1 ? 46 : .infinity
    }
    
    var onSuccess:(() -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(chunkedProviders, id: \.self) { chunk in
                HStack(spacing: 8) {
                    ForEach(chunk) { provider in
                        AsyncButton {
                            await signUp(provider: provider)
                        } label: {
                            AuthProviderButton(provider: provider, style: thirdPartyProviders.count > 2 ? .compact : .regular)
                                .padding(8)
                                .frame(maxWidth: providerButtonMaxWidth, minHeight: 30)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(clerkTheme.colors.textPrimary)
                        }
                        .buttonStyle(ClerkSecondaryButtonStyle())
                    }
                }
            }
        }
        .clerkErrorPresenting($errorWrapper)
    }
    
    private func signUp(provider: OAuthProvider) async {
        KeyboardHelpers.dismissKeyboard()
        do {
            try await signUp.create(.oauth(provider: provider))
            try await signUp.startExternalAuth()
            onSuccess?()
        } catch {
            if case ASWebAuthenticationSessionError.canceledLogin = error {
                return
            }
            
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
}

extension SignUpSocialProvidersView {
    
    func onSuccess(perform action: @escaping () -> Void) -> Self {
        var copy = self
        copy.onSuccess = action
        return copy
    }
    
}

#Preview {
    SignUpSocialProvidersView()
        .environmentObject(Clerk.mock)
        .padding()
}

#endif
