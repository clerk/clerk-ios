//
//  ExternalAuthUtils.swift
//
//
//  Created by Mike Pitre on 7/2/24.
//

import Foundation
import AuthenticationServices

enum ExternalAuthUtils {
    
    static func nonceFromCallbackUrl(url: URL) -> String? {
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
    
    #if canImport(AuthenticationServices) && !os(watchOS)
    /// Presents the native sign in with apple sheet to get an ASAuthorizationAppleIDCredential
    @MainActor
    static func getAppleIdCredential() async throws -> ASAuthorizationAppleIDCredential {
        let authManager = SignInWithAppleManager()
        let authorization = try await authManager.start()
        
        guard let appleIdCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw ClerkClientError(message: "Unable to get your Apple ID credential.")
        }
        
        return appleIdCredential
    }
    #endif
    
}

public struct ExternalAuthResult {
    public var signIn: SignIn?
    public var signUp: SignUp?
}
