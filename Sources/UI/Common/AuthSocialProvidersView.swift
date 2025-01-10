//
//  AuthSocialProvidersView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if os(iOS)

import SwiftUI
import Algorithms

struct AuthSocialProvidersView: View {
    var clerk = Clerk.shared
    @State private var errorWrapper: ErrorWrapper?
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var stackWidth: CGFloat = .zero
    
    enum UseCase {
        case signIn, signUp
    }

    var useCase: UseCase = .signIn
    var onSuccess:((_ externalAuthResult: ExternalAuthResult) -> Void)?
    
    private var socialProviders: [OAuthProvider] {
        (clerk.environment?.userSettings.authenticatableSocialProviders ?? []).sorted()
    }
    
    private var chunkedProviders: ChunksOfCountCollection<[OAuthProvider]> {
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
        .onGeometryChange(for: CGSize.self, of: { proxy in
            proxy.size
        }, action: { size in
            stackWidth = size.width
        })
    }
    
    private func startAuth(provider: OAuthProvider) async {
        KeyboardHelpers.dismissKeyboard()
        
        var externalAuthResult: ExternalAuthResult
        
        do {
			if provider == .apple {
                externalAuthResult = try await authenticateWithApple()
            } else {
                externalAuthResult = try await authenticateWithOAuth(provider: provider)
            }
            
            onSuccess?(externalAuthResult)
        } catch {
            if error.isCancelledError { return }
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func authenticateWithOAuth(provider: OAuthProvider) async throws -> ExternalAuthResult {
        var externalAuthResult: ExternalAuthResult
        
        switch useCase {
        case .signIn:
            externalAuthResult = try await SignIn
                .create(strategy: .oauth(provider))
                .authenticateWithRedirect()
        case .signUp:
            externalAuthResult = try await SignUp
                .create(strategy: .oauth(provider))
                .authenticateWithRedirect()
        }
        
        if let signUp = externalAuthResult.signUp,
           let externalAccountVerification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
           let error = externalAccountVerification.error {
            throw error
        }
        
        return externalAuthResult
    }
    
    private func authenticateWithApple() async throws -> ExternalAuthResult {
        let appleIdCredential = try await SignInWithAppleManager.getAppleIdCredential()
        
        guard let idToken = appleIdCredential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
            throw ClerkClientError(message: "Unable to get ID token from Apple ID Credential.")
        }
        
        var externalAuthResult: ExternalAuthResult
        
        switch useCase {
        case .signIn:
            externalAuthResult = try await SignIn
                .create(strategy: .idToken(provider: .apple, idToken: idToken))
                .authenticateWithIdToken()
            
        case .signUp:
            externalAuthResult = try await SignUp
                .create(
                    strategy: .idToken(
                        .apple,
                        idToken: idToken,
                        firstName: appleIdCredential.fullName?.givenName,
                        lastName: appleIdCredential.fullName?.familyName
                    )
                )
                .authenticateWithIdToken()
        }
        
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
