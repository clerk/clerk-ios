//
//  SignInSocialProvidersView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInSocialProvidersView: View {
    @EnvironmentObject private var clerk: Clerk
    
    private var thirdPartyProviders: [OAuthProvider] {
        clerk.environment.userSettings.enabledThirdPartyProviders.sorted()
    }
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    var onSuccess:(() -> Void)?
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: .init(.flexible()), count: min(thirdPartyProviders.count, thirdPartyProviders.count <= 2 ? 1 : 6)),
            alignment: .leading,
            content: {
                ForEach(thirdPartyProviders, id: \.self) { provider in
                    AsyncButton(options: [.disableButton], action: {
                        await signIn(provider: provider)
                    }, label: {
                        AuthProviderButton(provider: provider, style: thirdPartyProviders.count <= 2 ? .regular : .compact)
                            .font(.footnote)
                    })
                    .buttonStyle(.plain)
                }
            }
        )
    }
    
    private func signIn(provider: OAuthProvider) async {
        KeyboardHelpers.dismissKeyboard()
        do {
            try await signIn.create(.oauth(provider: provider))
            signIn.startOAuth { result in
                switch result {
                case .success:
                    onSuccess?()
                case .failure(let error):
                    dump(error)
                }
            }
        } catch {
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
