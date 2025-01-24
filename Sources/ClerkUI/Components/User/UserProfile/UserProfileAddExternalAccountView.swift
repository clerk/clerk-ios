//
//  UserProfileAddExternalAccountView.swift
//
//
//  Created by Mike Pitre on 11/9/23.
//

#if os(iOS)

import SwiftUI
import AuthenticationServices

struct UserProfileAddExternalAccountView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(ClerkTheme.self) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    @State private var errorWrapper: ErrorWrapper?
    
    private var user: User? {
        clerk.user
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Add connected account")
                    .font(.title2.weight(.bold))
                
                Text("Select a provider to connect your account.")
                    .font(.footnote)
                
                VStack {
                    ForEach(user?.unconnectedProviders ?? []) { provider in
                        AsyncButton {
                            await create(provider: provider)
                        } label: {
                            AuthProviderButton(
                                provider: provider,
                                label: "Connect \(provider.name) account"
                            )
                            .font(.footnote)
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(ClerkSecondaryButtonStyle())
                    }
                }
                
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkSecondaryButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.top, 30)
        }
        .clerkErrorPresenting($errorWrapper)
        .dismissButtonOverlay()
        .onChange(of: user) { oldValue, newValue in
            if newValue?.unconnectedProviders.count ?? 0 < oldValue?.unconnectedProviders.count ?? 0 {
                dismiss()
            }
        }
        .task {
            _ = try? await Clerk.Environment.get()
        }
    }
}

extension UserProfileAddExternalAccountView {
    
    private func create(provider: OAuthProvider) async {
        do {
            guard let user else { throw ClerkClientError(message: "Unable to find the current user.") }
            if provider == .apple {
                try await linkAppleAccount()
            } else {
                let newExternalAccount = try await user.createExternalAccount(provider)
                try await newExternalAccount.reauthorize()
            }
        } catch {
            if error.isCancelledError { return }
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    #if canImport(AuthenticationServices) && !os(watchOS)
    private func linkAppleAccount() async throws {
        
        guard let user else { throw ClerkClientError(message: "Unable to find the current user.") }
        
        let manager = SignInWithAppleManager()
        let authorization = try await manager.start()
        
        guard
            let appleIdCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = appleIdCredential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw ClerkClientError(message: "Unable to find your Apple ID credential.")
        }
        
        try await user.createExternalAccount(.apple, idToken: idToken)
    }
    #endif
    
}

#Preview {
    UserProfileAddExternalAccountView()
}

#endif
