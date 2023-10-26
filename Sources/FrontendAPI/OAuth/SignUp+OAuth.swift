//
//  SignUp+OAuth.swift
//
//
//  Created by Mike Pitre on 10/26/23.
//

import Foundation

extension SignUp {
    
    public func startOAuth(completion: @escaping (Result<Void, Error>) -> Void) throws {
        
        guard
            let verification = verifications.first(where: { $0.key == "external_account" })?.value,
            let redirectUrl = verification.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL not provided. Unable to start OAuth flow.")
        }
        
        let authSession = OAuthWebSession(url: url, authAction: .signUp) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
        
        DispatchQueue.main.async {
            authSession.start()
        }
    }
    
}
