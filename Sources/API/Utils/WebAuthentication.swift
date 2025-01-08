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
    
    private static var currentSession: ASWebAuthenticationSession?
    private static var continuation: CheckedContinuation<URL, any Error>?
    
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
    
    private static func completionHandler(_ url: URL?, error: Error?) -> Void {
        Self.currentSession = nil
        
        if let url {
            Self.continuation?.resume(returning: url)
        } else if let error {
            Self.continuation?.resume(throwing: error)
        } else {
            Self.continuation?.resume(throwing: ClerkClientError(message: "Missing callback URL"))
        }
    }
    
    func start() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            Self.continuation = continuation
                
            Self.currentSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Clerk.shared.redirectConfig.callbackUrlScheme,
                completionHandler: Self.completionHandler
            )

            #if !os(watchOS) && !os(tvOS)
            Self.currentSession?.presentationContextProvider = self
            #endif
            
            #if !os(tvOS)
            Self.currentSession?.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
            #endif
            
            Self.currentSession?.start()
        }
    }
    
    static func finishWithDeeplinkUrl(url: URL) {
        completionHandler(url, error: nil)
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
