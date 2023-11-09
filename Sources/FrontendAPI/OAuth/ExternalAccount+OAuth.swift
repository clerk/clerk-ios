//
//  ExternalAccount+OAuth.swift
//
//
//  Created by Mike Pitre on 11/9/23.
//

import Foundation

extension ExternalAccount {
    
    public func startOAuth(completion: @escaping (Result<Void, Error>) -> Void) {
        guard
            let redirectUrl = verification.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            completion(.failure(ClerkClientError(message: "Redirect URL not provided. Unable to start OAuth flow.")))
            return
        }
        
        let authSession = OAuthWebSession(url: url, authAction: .verify) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
                
        DispatchQueue.main.async {
            authSession.start()
        }
    }
    
}
