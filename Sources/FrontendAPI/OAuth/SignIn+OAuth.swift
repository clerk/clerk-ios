//
//  SignIn+OAuth.swift
//
//
//  Created by Mike Pitre on 10/26/23.
//

import Foundation

extension SignIn {
    
    public func startOAuth(completion: @escaping (Result<Void, Error>) -> Void) {
        guard
            let redirectUrl = firstFactorVerification?.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            completion(.failure(ClerkClientError(message: "Redirect URL not provided. Unable to start OAuth flow.")))
            return
        }
        
        let authSession = OAuthWebSession(url: url, authAction: .signIn) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
                
        DispatchQueue.main.async {
            authSession.start()
        }
    }
    
}
