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
    @Environment(Clerk.self) private var clerk
    @State private var errorWrapper: ErrorWrapper?
    @Environment(ClerkTheme.self) private var clerkTheme
    @State private var stackWidth: CGFloat = .zero
    
    enum UseCase {
        case signIn, signUp
    }

    var useCase: UseCase = .signIn
    var onSuccess:((_ transferFlowResult: TransferFlowResult) -> Void)?
    
    private var socialProviders: [OAuthProvider] {
        (clerk.environment.userSettings?.authenticatableSocialProviders ?? []).sorted()
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
        
        var transferFlowResult: TransferFlowResult
        
        do {
			if provider == .apple {
                transferFlowResult = try await authenticateWithApple()
            } else {
                transferFlowResult = try await authenticateWithOAuth(provider: provider)
            }
            
            onSuccess?(transferFlowResult)
        } catch {
            if error.isCancelledError { return }
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func authenticateWithOAuth(provider: OAuthProvider) async throws -> TransferFlowResult {
        var transferFlowResult: TransferFlowResult
        
        switch useCase {
        case .signIn:
            transferFlowResult = try await SignIn
                .authenticateWithRedirect(strategy: .oauth(provider: provider))
        case .signUp:
            transferFlowResult = try await SignUp
                .authenticateWithRedirect(strategy: .oauth(provider: provider))
        }
        
        if case .signUp(let signUp) = transferFlowResult,
           let externalAccountVerification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
           let error = externalAccountVerification.error  {
            throw error
        }
        
        return transferFlowResult
    }
    
    private func authenticateWithApple() async throws -> TransferFlowResult {
        let appleIdCredential = try await SignInWithAppleHelper().getAppleIdCredential()
        
        guard let idToken = appleIdCredential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
            throw ClerkClientError(message: "Unable to get ID token from Apple ID Credential.")
        }
        
        var transferFlowResult: TransferFlowResult
        
        switch useCase {
        case .signIn:
            transferFlowResult = try await SignIn
                .authenticateWithIdToken(provider: .apple, idToken: idToken)
            
        case .signUp:
            transferFlowResult = try await SignUp
                .create(
                    strategy: .idToken(
                        provider: .apple,
                        idToken: idToken,
                        firstName: appleIdCredential.fullName?.givenName,
                        lastName: appleIdCredential.fullName?.familyName
                    )
                )
                .authenticateWithIdToken()
        }
        
        return transferFlowResult
    }
}

extension AuthSocialProvidersView {
    
    func onSuccess(perform action: @escaping (_ transferFlowResult: TransferFlowResult) -> Void) -> Self {
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
