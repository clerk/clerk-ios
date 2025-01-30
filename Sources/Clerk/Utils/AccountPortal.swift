//
//  AccountPortal.swift
//  Clerk
//
//  Created by Mike Pitre on 1/29/25.
//

import Foundation
import AuthenticationServices

@MainActor
public final class AccountPortalManager: NSObject {
        
    public enum AuthType {
        case signIn, signUp
        
        @MainActor
        var url: URL? {
            switch self {
            case .signIn:
                guard let signInUrlString = Clerk.shared.environment.displayConfig?.signInUrl else {
                    return nil
                }
                return addRedirectQueryItemToUrlString(signInUrlString)
                
            case .signUp:
                guard let signUpUrlString = Clerk.shared.environment.displayConfig?.signUpUrl else {
                    return nil
                }
                return addRedirectQueryItemToUrlString(signUpUrlString)
            }
        }
        
        @MainActor
        private func addRedirectQueryItemToUrlString(_ url: String) -> URL? {
            guard var urlComponents = URLComponents(string: url) else { return nil }
            urlComponents.queryItems = (urlComponents.queryItems ?? []) + [URLQueryItem(name: "redirect_url", value: Clerk.shared.frontendApiUrl)]
            guard let urlWithRedirect = urlComponents.url else { return nil }
            return urlWithRedirect
        }
    }
    
    private var hostUrl: URL? {
        guard
            let urlComponents = URLComponents(string: Clerk.shared.frontendApiUrl),
            let host = urlComponents.host
        else {
            return nil
        }
        
        return URL(string: host)
    }
    
    public func startWebAuth(_ authType: AuthType, prefersEphemeralWebBrowserSession: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let authURL = authType.url, let hostUrl else {
                return continuation.resume(throwing: ClerkClientError(message: "URL not provided"))
            }
            
            var session: ASWebAuthenticationSession
            
            if #available(iOS 17.4, watchOS 10.4, *) {
                session = ASWebAuthenticationSession(
                    url: authURL,
                    callback: .https(host: hostUrl.absoluteString, path: ""),
                    completionHandler: { url, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                )
            } else {
                session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: hostUrl.scheme
                ) { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            
            #if !os(watchOS) && !os(tvOS)
            session.presentationContextProvider = self
            #endif

            #if !os(tvOS)
            session.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
            #endif

            session.start()
        }
    }

}

#if !os(watchOS) && !os(tvOS)
extension AccountPortalManager: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
#endif
