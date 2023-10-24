//
//  OAuthSession.swift
//
//
//  Created by Mike Pitre on 10/19/23.
//

import AuthenticationServices

public final class OAuthWebSession: NSObject, ObservableObject {
    var webAuthSession: ASWebAuthenticationSession?
    var authAction: AuthAction = .signIn
    
    public enum AuthAction {
        case signIn, signUp
    }
        
    public init(url: URL, authAction: AuthAction, onSuccess: (() -> Void)? = nil) {
        super.init()
        
        self.webAuthSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "clerk",
            completionHandler: { callbackUrl, error in
                guard let callbackUrl else { return }
                Task {
                    do {
                        try await Clerk.shared.client.get()
                        
                        switch authAction {
                        case .signIn:
                            if Clerk.shared.client.signIn.firstFactorVerification?.status == .transferable {
                                try await Clerk.shared.client.signUp.create(.init(transfer: true))
                            } else {
                                let nonce = self.nonceFromCallbackUrl(url: callbackUrl)
                                try await Clerk.shared.client.signIn.get(.init(rotatingTokenNonce: nonce))
                            }
                            
                        case .signUp:
                            if
                                let verification = Clerk.shared.client.signUp.verifications.first(where: { $0.key == "external_account" })?.value,
                                verification.status == .transferable
                            {
                                try await Clerk.shared.client.signIn.create(.init(transfer: true))
                            } else {
                                let nonce = self.nonceFromCallbackUrl(url: callbackUrl)
                                try await Clerk.shared.client.signUp.get(.init(rotatingTokenNonce: nonce))
                            }
                        }
                        
                        onSuccess?()
                    } catch {
                        dump(error)
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

