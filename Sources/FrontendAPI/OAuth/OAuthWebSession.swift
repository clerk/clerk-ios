//
//  OAuthSession.swift
//
//
//  Created by Mike Pitre on 10/19/23.
//

import AuthenticationServices

public final class OAuthWebSession: NSObject, ObservableObject {
    var webAuthSession: ASWebAuthenticationSession?
        
    public init(url: URL, onSuccess: (() -> Void)? = nil) {
        super.init()
        
        self.webAuthSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "clerk",
            completionHandler: { callbackUrl, error in
                if let callbackUrl, let nonce = self.nonceFromCallbackUrl(url: callbackUrl) {
                    Task {
                        do {
                            try await Clerk.shared.client.signIn.get(rotatingTokenNonce: nonce)
                            onSuccess?()
                        } catch {
                            dump(error)
                        }
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

