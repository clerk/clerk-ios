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
    
    var onSuccess:((_ externalAuthResult: ExternalAuthResult) -> Void)?
    
    private var socialProviders: [SocialProvider] {
        (clerk.environment?.userSettings.authenticatableSocialProviders ?? []).sorted()
    }
    
    private var chunkedProviders: ChunksOfCountCollection<[SocialProvider]> {
        socialProviders.chunks(ofCount: 4)
    }
        
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chunkedProviders, id: \.self) { chunk in
                HStack(spacing: 8) {
                    ForEach(chunk) { provider in
                        AsyncButton {
                            await startAuth(provider: provider)
                        } label: {
                            AuthProviderButton(provider: provider, style: socialProviders.count > 2 ? .compact : .regular)
                                .frame(
                                    maxWidth: socialProviders.count <= 4 ? .infinity : max((stackWidth - 24) / 4, 0),
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
    
    private func startAuth(provider: SocialProvider) async {
        KeyboardHelpers.dismissKeyboard()

		var externalAuthResult: ExternalAuthResult?        

        do {
			if provider == .apple {
                externalAuthResult = try await signUpWithApple()
            } else {
            	externalAuthResult = try await SignIn
                	.create(strategy: .social(provider))
                	.authenticateWithRedirect()
			}
            
            if let externalAuthResult {
                onSuccess?(externalAuthResult)
            }
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func signUpWithApple() async throws -> ExternalAuthResult? {
        guard let appleIdCredential = try await ExternalAuthUtils.getAppleIdCredential() else {
            return nil
        }
        
        guard let token = appleIdCredential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
            throw ClerkClientError(message: "Unable to get ID token from Apple ID Credential.")
        }
                        
        let authCode = appleIdCredential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) })
        
        let externalAuthResult = try await SignUp.signUpWithAppleIdToken(
            idToken: token,
            code: authCode,
            firstName: appleIdCredential.fullName?.givenName,
            lastName: appleIdCredential.fullName?.familyName
        )
        
        return externalAuthResult
    }
}

extension AuthSocialProvidersView {
    
    func onSuccess(perform action: @escaping (_ externalAuthResult: ExternalAuthResult) -> Void) -> Self {
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
