//
//  AuthSocialProvidersView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(UIKit)

import SwiftUI
import AuthenticationServices
import Algorithms

struct AuthSocialProvidersView: View {
    @EnvironmentObject private var clerk: Clerk
    @State private var errorWrapper: ErrorWrapper?
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var viewSize: CGSize?
    
    private let buttonMinWidth: CGFloat = 46
    
    let useCase: UseCase
    var onSuccess:(() -> Void)?
    
    enum UseCase {
        case signIn, signUp
    }
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    private var signUp: SignUp {
        clerk.client.signUp
    }
    
    private var thirdPartyProviders: [ExternalProvider] {
        clerk.environment.userSettings.enabledThirdPartyProviders.sorted()
    }
    
    private var chunkedProviders: ChunksOfCountCollection<[ExternalProvider]> {
        thirdPartyProviders.chunks(ofCount: Int(mostHorizontalButtons))
    }
    
    private var mostHorizontalButtons: CGFloat {
        if let viewSize {
            return max(1, (viewSize.width + 8) / (buttonMinWidth + 8))
        } else {
            return 6
        }
    }
        
    private var providerButtonMaxWidth: CGFloat {
        chunkedProviders.count > 1 ? buttonMinWidth : .infinity
    }
        
    var body: some View {
        VStack(spacing: 8) {
            ForEach(chunkedProviders, id: \.self) { chunk in
                HStack(spacing: 8) {
                    ForEach(chunk) { provider in
                        AsyncButton {
                            switch useCase {
                            case .signIn:
                                await signIn(provider: provider)
                            case .signUp:
                                await signUp(provider: provider)
                            }
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
        .frame(maxWidth: .infinity)
        .readSize { size in
            withAnimation(nil) { viewSize = size }
        }
        .clerkErrorPresenting($errorWrapper)
    }
    
    private func signIn(provider: ExternalProvider) async {
        KeyboardHelpers.dismissKeyboard()
        do {
            try await signIn.create(strategy: .externalProvider(provider))
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
    
    private func signUp(provider: ExternalProvider) async {
        KeyboardHelpers.dismissKeyboard()
        do {
            try await signUp.create(.externalProvider(provider))
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

extension AuthSocialProvidersView {
    
    func onSuccess(perform action: @escaping () -> Void) -> Self {
        var copy = self
        copy.onSuccess = action
        return copy
    }
    
}

#Preview {
    AuthSocialProvidersView(useCase: .signIn)
        .padding()
        .environmentObject(Clerk.mock)
}

#endif
