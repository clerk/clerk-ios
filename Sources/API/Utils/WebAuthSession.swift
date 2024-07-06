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
            
            func handleCompletion(callbackUrl: URL?, error: (any Error)?) {
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
            
            let webAuthSession: ASWebAuthenticationSession
            
            if #available(iOS 17.4, watchOS 10.4, macOS 14.4, visionOS 1.1, *) {
                
                webAuthSession = ASWebAuthenticationSession(
                    url: url,
                    callback: .customScheme(Clerk.shared.redirectConfig.callbackUrlScheme),
                    completionHandler: handleCompletion
                )
                
            } else {
                
                // Fallback on earlier versions
                webAuthSession = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: Clerk.shared.redirectConfig.callbackUrlScheme,
                    completionHandler: handleCompletion
                )
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
