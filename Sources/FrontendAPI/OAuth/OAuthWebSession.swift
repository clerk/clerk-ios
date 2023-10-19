//
//  OAuthSession.swift
//
//
//  Created by Mike Pitre on 10/19/23.
//

import AuthenticationServices

public final class OAuthWebSession: NSObject, ObservableObject {
    var webAuthSession: ASWebAuthenticationSession?
    
    public init(url: URL) {
        super.init()
        
        self.webAuthSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "clerkexample",
            completionHandler: { callbackUrl, error in
                Task {
                    do {
                        try await Clerk.shared.client.get()
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
    
}

extension OAuthWebSession: ASWebAuthenticationPresentationContextProviding {
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
    
}

