//
//  OAuthSession.swift
//
//
//  Created by Mike Pitre on 10/19/23.
//

import AuthenticationServices

public final class ExternalAuthWebSession: NSObject {
    let url: URL
    let authAction: AuthAction
    
    public enum AuthAction {
        case signIn, signUp, verify
    }
    
    private var webAuthSession: ASWebAuthenticationSession?
    
    public init(url: URL, authAction: AuthAction = .signIn) {
        self.url = url
        self.authAction = authAction
    }
    
    @MainActor
    public func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let webAuthSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "clerk") { callbackUrl, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackUrl {
                    Task {
                        do {
                            switch self.authAction {
                                
                            case .signIn:
                                if let nonce = self.nonceFromCallbackUrl(url: callbackUrl) {
                                    try await Clerk.shared.client.signIn.get(rotatingTokenNonce: nonce)
                                    
                                } else {
                                    try await Clerk.shared.client.get()
                                    if Clerk.shared.client.signIn.firstFactorVerification?.status == .transferable {
                                        try await Clerk.shared.client.signUp.create(.transfer)
                                    }
                                }
                                
                            case .signUp:
                                if let nonce = self.nonceFromCallbackUrl(url: callbackUrl) {
                                    try await Clerk.shared.client.signUp.get(rotatingTokenNonce: nonce)
                                    
                                } else {
                                    try await Clerk.shared.client.get()
                                    if
                                        let verification = Clerk.shared.client.signUp.verifications.first(where: { $0.key == "external_account" })?.value,
                                        verification.status == .transferable
                                    {
                                        try await Clerk.shared.client.signIn.create(strategy: .transfer)
                                    }
                                }
                                
                            case .verify:
                                try await Clerk.shared.client.get()
                            }
                            
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }

            webAuthSession.presentationContextProvider = self
            webAuthSession.prefersEphemeralWebBrowserSession = true
            webAuthSession.start()
        }
    }
    
    private func nonceFromCallbackUrl(url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }
        
        guard let nonceQueryItem = components.queryItems?.first(where: { item in
            item.name == "rotating_token_nonce"
        }) else {
            return nil
        }
        
        return nonceQueryItem.value
    }
    
}

extension ExternalAuthWebSession: ASWebAuthenticationPresentationContextProviding {
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
    
}

