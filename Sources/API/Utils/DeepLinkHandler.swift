//
//  DeepLinkHandler.swift
//  Clerk
//
//  Created by Mike Pitre on 8/21/24.
//

import Foundation

extension Clerk {
    
    public static func handleUrl(_ url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        
        switch components {
            
        case let x where x.path.contains("oauth_callback"):
            await handleOAuthCallback(urlComponents: components)
            
        default:
            return
        }
    }
    
    @MainActor
    private static func handleOAuthCallback(urlComponents: URLComponents) async {
        #if !os(tvOS)
        guard let finalRedirectUrl = urlComponents.queryItems?.first(
            where: { $0.name == "_final_redirect_url" }
        )?.value else {
            return
        }
        
        guard let url = URL(string: finalRedirectUrl) else {
            return
        }
        
        do {
            if try await SignIn.handleOAuthCallbackUrl(url) != nil {
                WebAuthentication.currentSession?.cancel()
                return
            }
            
            if try await SignUp.handleOAuthCallbackUrl(url) != nil {
                WebAuthentication.currentSession?.cancel()
                return
            }
        } catch {
            dump(error)
        }
        #endif
    }
    
}
