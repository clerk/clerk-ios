//
//  File.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

import Foundation

extension SignIn {
    
    /// Represents the parameters used for authenticating with a redirect.
    ///
    /// This structure is used to authenticate a user with various strategies, including OAuth, SAML, and enterprise SSO. It defines the necessary parameters for the authentication process, such as the redirect URLs and legal acceptance.
    ///
    /// - SeeAlso: `AuthenticateWithRedirect` function for initiating authentication with these parameters.
    struct AuthenticateWithRedirectParams: Encodable {
        
        /// The strategy to use for authentication.
        let strategy: String
        
        /// The full URL or path that the OAuth provider should redirect to, on successful authorization on their part.
        let redirectUrl: String
        
        /// The full URL or path that the user will be redirected to once the sign-in is complete.
        let redirectUrlComplete: String
        
        /// The email address used to target an enterprise connection during sign-in. This is optional and only used when the strategy involves enterprise authentication.
        var emailAddress: String?
        
        /// A boolean indicating whether the user has agreed to the legal compliance documents. This is an optional field.
        var legalAccepted: Bool?
        
        /// The identifier associated with the user or the authentication session. This is an optional field.
        var identifier: String?
    }
    
    /// The strategy to use for authentication.
    public enum AuthenticateWithRedirectStrategy: Codable, Sendable {
        /// The user will be authenticated with their social connection account.
        case oauth(provider: OAuthProvider)
        
        /// The user will be authenticated with their enterprise SSO account.
        case enterpriseSSO(identifier: String)
        
        var signInStrategy: SignIn.CreateStrategy {
            switch self {
            case .oauth(let provider):
                return .oauth(provider: provider)
            case .enterpriseSSO(let identifier):
                return .enterpriseSSO(identifier: identifier)
            }
        }
        
        @MainActor
        var params: AuthenticateWithRedirectParams {
            switch self {
            case .oauth(let provider):
                    .init(
                        strategy: provider.strategy,
                        redirectUrl: Clerk.shared.redirectConfig.redirectUrl,
                        redirectUrlComplete: Clerk.shared.redirectConfig.redirectUrl
                    )
            case .enterpriseSSO(let identifier):
                    .init(
                        strategy: "enterprise_sso",
                        redirectUrl: Clerk.shared.redirectConfig.redirectUrl,
                        redirectUrlComplete: Clerk.shared.redirectConfig.redirectUrl,
                        identifier: identifier
                    )
            }
        }
    }
    
}
