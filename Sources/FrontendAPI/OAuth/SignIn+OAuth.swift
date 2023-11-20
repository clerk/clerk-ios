//
//  SignIn+OAuth.swift
//
//
//  Created by Mike Pitre on 10/26/23.
//

import Foundation

extension SignIn {
    
    public func startOAuth() async throws {
        guard
            let redirectUrl = firstFactorVerification?.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL not provided. Unable to start OAuth flow.")
        }
        
        let authSession = OAuthWebSession(url: url, authAction: .signIn)
        try await authSession.start()
    }
    
}
