//
//  ASWebAuthManager.swift
//
//
//  Created by Mike Pitre on 10/19/23.
//

import AuthenticationServices

public struct WebAuthResult {
    var cancelled: Bool = false
    var wasTransfer: Bool = false
}

@available(tvOS 16.0, watchOS 6.2, *)
@MainActor
final class ExternalAuthWebSession: NSObject {
    let url: URL
    let prefersEphemeralWebBrowserSession: Bool
    
    init(url: URL, prefersEphemeralWebBrowserSession: Bool = false) {
        self.url = url
        self.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
    }
    
    @discardableResult
    func start() async throws -> WebAuthResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WebAuthResult, Error>) in
            let webAuthSession = ASWebAuthenticationSession(url: url, callbackURLScheme: Clerk.shared.redirectConfig.callbackUrlScheme) { callbackUrl, error in
                
                if let error = error {
                    
                    if case ASWebAuthenticationSessionError.canceledLogin = error {
                        continuation.resume(returning: WebAuthResult(cancelled: true))
                    } else {
                        continuation.resume(throwing: error)
                    }
                    
                } else if let callbackUrl {
                    
                    Task {
                        do {
                            var result = WebAuthResult()
                            
                            if let nonce = self.nonceFromCallbackUrl(url: callbackUrl) {
                                try await Clerk.shared.client?.signIn?.get(rotatingTokenNonce: nonce)
                                
                            } else {
                                try await Clerk.shared.client?.get()
                                if Clerk.shared.client?.signIn?.firstFactorVerification?.status == .transferable {
                                    try await SignUp.create(strategy: .transfer)
                                    result.wasTransfer = true
                                }
                            }
                            
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    
                }
            }

            #if !os(watchOS) && !os(tvOS)
            webAuthSession.presentationContextProvider = self
            #endif
            webAuthSession.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
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

#if !os(watchOS) && !os(tvOS)
extension ExternalAuthWebSession: ASWebAuthenticationPresentationContextProviding {
    
    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
    
}
#endif
