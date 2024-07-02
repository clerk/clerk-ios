//
//  WebAuthSession.swift
//
//
//  Created by Mike Pitre on 10/19/23.
//

import AuthenticationServices

@available(tvOS 16.0, watchOS 6.2, *)
@MainActor
final class WebAuthSession: NSObject {
    let url: URL
    let prefersEphemeralWebBrowserSession: Bool
    
    init(
        url: URL,
        prefersEphemeralWebBrowserSession: Bool = false
    ) {
        self.url = url
        self.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
    }
    
    func start() async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            
            let webAuthSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Clerk.shared.redirectConfig.callbackUrlScheme
            ) { callbackUrl, error in
                if let error {
                    if case ASWebAuthenticationSessionError.canceledLogin = error {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else if let callbackUrl {
                    continuation.resume(returning: callbackUrl)
                } else {
                    continuation.resume(throwing: ClerkClientError(message: "Missing callback URL"))
                }
            }

            #if !os(watchOS) && !os(tvOS)
            webAuthSession.presentationContextProvider = self
            #endif
            
            #if !os(tvOS)
            webAuthSession.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
            #endif
            
            webAuthSession.start()
        }
    }
    
}

#if !os(watchOS) && !os(tvOS)
extension WebAuthSession: ASWebAuthenticationPresentationContextProviding {
    
    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
    
}
#endif
