//
//  ExternalAccount+OAuth.swift
//
//
//  Created by Mike Pitre on 11/9/23.
//

import Foundation

extension ExternalAccount {
    
    public func startOAuth() async throws {
        guard
            let redirectUrl = verification.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL not provided. Unable to start OAuth flow.")
        }
        
        let authSession = OAuthWebSession(url: url, authAction: .verify)
        try await authSession.start()
    }
    
}
