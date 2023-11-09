//
//  OAuthSession.swift
//
//
//  Created by Mike Pitre on 10/19/23.
//

import AuthenticationServices

public final class OAuthWebSession: NSObject {
    var webAuthSession: ASWebAuthenticationSession?
    var authAction: AuthAction = .signIn
    
    public enum AuthAction {
        case signIn, signUp, verify
    }
        
    public init(url: URL, authAction: AuthAction, completion: ((Result<Void, Error>) -> Void)?) {
        super.init()
        
        self.webAuthSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "clerk",
            completionHandler: { callbackUrl, error in
                guard let callbackUrl else { return }
                Task {
                    do {
                        switch authAction {
                            
                        case .signIn:
                            if let nonce = self.nonceFromCallbackUrl(url: callbackUrl) {
                                try await Clerk.shared.client.signIn.get(.init(rotatingTokenNonce: nonce))
                                
                            } else {
                                try await Clerk.shared.client.get()
                                if Clerk.shared.client.signIn.firstFactorVerification?.status == .transferable {
                                    try await Clerk.shared.client.signUp.create(.transfer)
                                }
                            }
                            
                        case .signUp:
                            if let nonce = self.nonceFromCallbackUrl(url: callbackUrl) {
                                try await Clerk.shared.client.signUp.get(.init(rotatingTokenNonce: nonce))
                                
                            } else {
                                try await Clerk.shared.client.get()
                                if
                                    let verification = Clerk.shared.client.signUp.verifications.first(where: { $0.key == "external_account" })?.value,
                                    verification.status == .transferable
                                {
                                    try await Clerk.shared.client.signIn.create(.transfer)
                                }
                            }
                            
                        case .verify:
                            try await Clerk.shared.client.get()
                        }
                        
                        completion?(.success(()))
                    } catch {
                        completion?(.failure(error))
                    }
                }
            }
        )
        
        webAuthSession?.presentationContextProvider = self
        webAuthSession?.prefersEphemeralWebBrowserSession = true
    }
    
    public func start() {
        webAuthSession?.start()
    }
    
    public func cancel() {
        webAuthSession?.cancel()
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

extension OAuthWebSession: ASWebAuthenticationPresentationContextProviding {
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
    
}

