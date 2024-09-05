//
//  WebAuthSession.swift
//
//
//  Created by Mike Pitre on 10/19/23.
//

import AuthenticationServices

@available(tvOS 16.0, watchOS 6.2, *)
@MainActor
final class WebAuthentication: NSObject {
    let url: URL
    let prefersEphemeralWebBrowserSession: Bool
    
    static var currentSession: ASWebAuthenticationSession?
    
    init(
        url: URL,
        prefersEphemeralWebBrowserSession: Bool = false
    ) {
        self.url = url
        self.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
    }
    
    private var urlComponents: URLComponents? {
        let url = URL(string: Clerk.shared.frontendAPIURL)!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components
    }
    
    func start() async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
                        
//            if #available(iOS 17.4, watchOS 10.4, macOS 14.4, visionOS 1.1, *) {
//                
//                Self.currentSession = ASWebAuthenticationSession(
//                    url: url,
//                    callback: .https(
//                        host: urlComponents?.host ?? "",
//                        path: "/v1/oauth_callback"
//                    ),
//                    completionHandler: { url, error in
//                        Self.currentSession = nil
//                        
//                        if let error {
//                            if case ASWebAuthenticationSessionError.canceledLogin = error {
//                                continuation.resume(returning: nil)
//                            } else {
//                                continuation.resume(throwing: error)
//                            }
//                        } else if let url,
//                                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
//                                  let value = components.queryItems?.first(where: { $0.name == "_final_redirect_url" })?.value,
//                                  let redirectUrl = URL(string: value) {
//                            continuation.resume(returning: redirectUrl)
//                        } else {
//                            continuation.resume(throwing: ClerkClientError(message: "Missing callback URL"))
//                        }
//                    }
//                )
//
//            } else {
                
                // Fallback on earlier versions
                Self.currentSession = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: Clerk.shared.redirectConfig.callbackUrlScheme,
                    completionHandler: { url, error in
                        Self.currentSession = nil
                        
                        if let error {
                            if case ASWebAuthenticationSessionError.canceledLogin = error {
                                continuation.resume(returning: nil)
                            } else {
                                continuation.resume(throwing: error)
                            }
                        } else if let url {
                            continuation.resume(returning: url)
                        } else {
                            continuation.resume(throwing: ClerkClientError(message: "Missing callback URL"))
                        }
                    }
                )
//            }

            #if !os(watchOS) && !os(tvOS)
            Self.currentSession?.presentationContextProvider = self
            #endif
            
            #if !os(tvOS)
            Self.currentSession?.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
            #endif
            
            Self.currentSession?.start()
        }
    }
    
    func cancel() {
        Self.currentSession?.cancel()
        Self.currentSession = nil
    }
    
}

#if !os(watchOS) && !os(tvOS)
extension WebAuthentication: ASWebAuthenticationPresentationContextProviding {
    
    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
    
}
#endif