//
//  ASWebAuthManager.swift
//
//
//  Created by Mike Pitre on 10/19/23.
//

import AuthenticationServices

public typealias NeedsTransferToSignUp = Bool

@available(tvOS 16.0, watchOS 6.2, *)
@MainActor
final class ASWebAuthManager: NSObject {
    let url: URL
    let prefersEphemeralWebBrowserSession: Bool
    
    init(
        url: URL,
        prefersEphemeralWebBrowserSession: Bool = false
    ) {
        self.url = url
        self.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
    }
    
    @discardableResult
    func start() async throws -> NeedsTransferToSignUp {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NeedsTransferToSignUp, Error>) in
            let webAuthSession = ASWebAuthenticationSession(url: url, callbackURLScheme: Clerk.shared.redirectConfig.callbackUrlScheme) { callbackUrl, error in
                
                if let error = error {
                    
                    if case ASWebAuthenticationSessionError.canceledLogin = error {
                        continuation.resume(returning: false)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    
                } else if let callbackUrl {
                    
                    Task {
                        do {
                            
                            if let nonce = self.nonceFromCallbackUrl(url: callbackUrl) {
                                
                                try await Clerk.shared.client?.signIn?.get(rotatingTokenNonce: nonce)
                                continuation.resume(returning: false)
                                
                            } else {
                                
                                try await Client.get()
                                let needsTransferToSignUp = Clerk.shared.client?.signIn?.firstFactorVerification?.status == .transferable
                                let botProtectionIsEnabled = Clerk.shared.environment?.displayConfig.botProtectionIsEnabled == true
                                
                                if needsTransferToSignUp {
                                    if botProtectionIsEnabled {
                                        continuation.resume(returning: true)
                                    } else {
                                        try await SignUp.create(strategy: .transfer)
                                        continuation.resume(returning: false)
                                    }
                                } else {
                                    continuation.resume(returning: false)
                                }
                                
                            }
                            
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    
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
extension ASWebAuthManager: ASWebAuthenticationPresentationContextProviding {
    
    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
    
}
#endif
