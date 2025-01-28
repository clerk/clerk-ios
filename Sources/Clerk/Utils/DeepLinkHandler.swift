//
//  DeepLinkHandler.swift
//  Clerk
//
//  Created by Mike Pitre on 8/21/24.
//

import Foundation

extension Clerk {
    
    static func handleUrl(_ url: URL) async {
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
        guard let finalRedirectUrl = urlComponents.queryItems?.first(
            where: { $0.name == "_final_redirect_url" }
        )?.value else {
            return
        }
                
        guard let url = URL(string: finalRedirectUrl) else {
            return
        }
        
        WebAuthentication.finishWithDeeplinkUrl(url: url)
    }
    
}
