//
//  WebAuthSession.swift
//
//
//  Created by Mike Pitre on 10/19/23.
//

import AuthenticationServices

actor WebAuthSessionManager {
    private var currentSession: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<URL, any Error>?
    
    func setSession(_ session: ASWebAuthenticationSession, continuation: CheckedContinuation<URL, any Error>) {
        self.currentSession = session
        self.continuation = continuation
    }
    
    func completeSession(with url: URL?, error: Error?) {
        defer {
            currentSession = nil
            continuation = nil
        }
        
        guard let continuation = continuation else {
            dump("Continuation already completed. Ignoring.")
            return
        }
        
        if let url {
            continuation.resume(returning: url)
        } else if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume(throwing: ClerkClientError(message: "Missing callback URL"))
        }
    }
}


@available(tvOS 16.0, watchOS 6.2, *)
@MainActor
final class WebAuthentication: NSObject {
    private static let sessionManager = WebAuthSessionManager()
    
    let url: URL
    let prefersEphemeralWebBrowserSession: Bool
    
    init(url: URL, prefersEphemeralWebBrowserSession: Bool = false) {
        self.url = url
        self.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
    }
    
    func start() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: Clerk.shared.redirectConfig.callbackUrlScheme,
                    completionHandler: { [weak self] url, error in
                        Task {
                            await WebAuthentication.sessionManager.completeSession(with: url, error: error)
                        }
                    }
                )
                
                #if !os(watchOS) && !os(tvOS)
                session.presentationContextProvider = self
                #endif
                
                #if !os(tvOS)
                session.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
                #endif
                
                await WebAuthentication.sessionManager.setSession(session, continuation: continuation)
                session.start()
            }
        }
    }
    
    static func finishWithDeeplinkUrl(url: URL) {
        Task {
            await sessionManager.completeSession(with: url, error: nil)
        }
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

