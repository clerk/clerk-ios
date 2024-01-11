//
//  SignIn+OAuth.swift
//
//
//  Created by Mike Pitre on 10/26/23.
//

import Foundation

extension SignIn {
    
    public func startExternalAuth() async throws {
        guard
            let redirectUrl = firstFactorVerification?.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL not provided. Unable to start authentication flow.")
        }
        
        let authSession = ExternalAuthWebSession(url: url, authAction: .signIn)
        try await authSession.start()
    }
    
}
