//
//  AuthSocialProvidersView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if os(iOS)

import SwiftUI
import Algorithms
import AuthenticationServices

struct AuthSocialProvidersView: View {
    @ObservedObject private var clerk = Clerk.shared
    @State private var errorWrapper: ErrorWrapper?
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var stackWidth: CGFloat = .zero
    
    var onSuccess:((_ oauthResult: OAuthResult) -> Void)?
    
    private var oauthProviders: [OAuthProvider] {
        (clerk.environment?.userSettings.enabledOAuthProviders ?? []).sorted()
    }
    
    private var chunkedProviders: ChunksOfCountCollection<[OAuthProvider]> {
        oauthProviders.chunks(ofCount: 4)
    }
        
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chunkedProviders, id: \.self) { chunk in
                HStack(spacing: 8) {
                    ForEach(chunk) { provider in
                        AsyncButton {
                            await startAuth(provider: provider)
                        } label: {
                            AuthProviderButton(provider: provider, style: oauthProviders.count > 2 ? .compact : .regular)
                                .frame(
                                    maxWidth: oauthProviders.count <= 4 ? .infinity : max((stackWidth - 24) / 4, 0),
                                    minHeight: 30
                                )
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(clerkTheme.colors.textPrimary)
                        }
                        .buttonStyle(ClerkSecondaryButtonStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .clerkErrorPresenting($errorWrapper)
        .readSize { stackSize in
            stackWidth = stackSize.width
        }
    }
    
    private func startAuth(provider: OAuthProvider) async {
        KeyboardHelpers.dismissKeyboard()

		var oauthResult: OAuthResult?        

        do {
			if provider == .apple {
                oauthResult = try await SignUp.signUpWithApple()
            } else {
            	oauthResult = try await SignIn
                	.create(strategy: .oauth(provider))
                	.authenticateWithRedirect()
			}
            
            if let oauthResult {
                onSuccess?(oauthResult)
            }
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
}

extension AuthSocialProvidersView {
    
    func onSuccess(perform action: @escaping (_ oauthResult: OAuthResult) -> Void) -> Self {
        var copy = self
        copy.onSuccess = action
        return copy
    }
    
}

#Preview {
    AuthSocialProvidersView()
        .padding()
}

#endif
