//
//  ExternalAccount+OAuth.swift
//
//
//  Created by Mike Pitre on 11/9/23.
//

import Foundation

extension ExternalAccount {
    
    public func startExternalAuth() async throws {
        guard
            let redirectUrl = verification.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL not provided. Unable to start external authentication flow.")
        }
        
        let authSession = ExternalAuthWebSession(url: url, authAction: .verify)
        try await authSession.start()
    }
    
}
