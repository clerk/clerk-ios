//
//  SignUpSocialProvidersView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignUpSocialProvidersView: View {
    @EnvironmentObject private var clerk: Clerk
    
    private var thirdPartyProviders: [OAuthProvider] {
        clerk.environment.userSettings.enabledThirdPartyProviders.sorted()
    }
    
    private var signUp: SignUp {
        clerk.client.signUp
    }
    
    var onSuccess:(() -> Void)?
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: .init(.flexible()), count: min(thirdPartyProviders.count, thirdPartyProviders.count <= 2 ? 1 : 6)),
            alignment: .leading,
            content: {
                ForEach(thirdPartyProviders, id: \.self) { provider in
                    AsyncButton(options: [.disableButton], action: {
                        await signUp(provider: provider)
                    }, label: {
                        AuthProviderButton(provider: provider, style: thirdPartyProviders.count <= 2 ? .regular : .compact)
                            .font(.footnote)
                    })
                    .buttonStyle(.plain)
                }
            }
        )
    }
    
    private func signUp(provider: OAuthProvider) async {
        KeyboardHelpers.dismissKeyboard()
        do {
            try await signUp.create(.oauth(provider: provider))
            try await signUp.startOAuth()
            onSuccess?()
        } catch {
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
