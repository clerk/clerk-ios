//
//  SignInSocialProvidersView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import AuthenticationServices

struct SignInSocialProvidersView: View {
    @EnvironmentObject private var clerk: Clerk
    @State private var errorWrapper: ErrorWrapper?
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var providerStackSize: CGSize = .zero
    @State private var providerButtonSize: CGSize = .zero
    
    private var thirdPartyProviders: [OAuthProvider] {
        clerk.environment.userSettings.enabledThirdPartyProviders.sorted()
    }
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
        
    private var providerButtonMaxWidth: CGFloat {
        providerStackSize.height > providerButtonSize.height ? 46 : .infinity
    }
    
    var onSuccess:(() -> Void)?
    
    var body: some View {
        WrappingHStack(thirdPartyProviders, alignment: .center, spacing: .constant(8), lineSpacing: 8) { provider in
            AsyncButton {
                await signIn(provider: provider)
            } label: {
                AuthProviderButton(provider: provider, style: thirdPartyProviders.count > 2 ? .compact : .regular)
                    .padding(8)
                    .frame(minWidth: 46, maxWidth: providerButtonMaxWidth, minHeight: 30)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(clerkTheme.colors.textPrimary)
                    .readSize { providerButtonSize = $0 }
            }
            .buttonStyle(ClerkSecondaryButtonStyle())
        }
        .readSize { providerStackSize = $0 }
        .clerkErrorPresenting($errorWrapper)
    }
    
    private func signIn(provider: OAuthProvider) async {
        KeyboardHelpers.dismissKeyboard()
        do {
            try await signIn.create(.oauth(provider: provider))
            try await signIn.startExternalAuth()
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

extension SignInSocialProvidersView {
    
    func onSuccess(perform action: @escaping () -> Void) -> Self {
        var copy = self
        copy.onSuccess = action
        return copy
    }
    
}

#Preview {
    SignInSocialProvidersView()
        .padding()
        .environmentObject(Clerk.mock)
}

#endif
