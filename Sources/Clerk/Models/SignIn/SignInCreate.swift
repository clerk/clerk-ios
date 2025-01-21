//
//  SignInCreate.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

import Foundation

extension SignIn {
    
    /// Represents the various strategies for creating a `SignIn` request.
    public enum CreateStrategy {
        
        /// The user will be authenticated either through SAML or OIDC depending on the configuration of their enterprise SSO account.
        ///
        /// - Parameters:
        ///   - emailAddress: The email address associated with the user's enterprise SSO account.
        case enterpriseSSO(_ emailAddress: String)
        
        /// The user will be authenticated with an ID token provider, such as SignInWithApple.
        ///
        /// - Parameters:
        ///   - provider: The ID token provider used for authentication (e.g., SignInWithApple).
        ///   - idToken: The ID token issued by the provider for authentication.
        case idToken(provider: IDTokenProvider, idToken: String)

        /// The user will be authenticated with the provided identifier.
        ///
        /// - Parameters:
        ///   - identifier: The authentication identifier for the sign-in. This can be the user's email address, phone number, username, or Web3 wallet address.
        ///   - password: The user's password. Only supported if password authentication is enabled.
        case identifier(_ identifier: String, password: String? = nil)

        /// The user will be authenticated with their social connection account.
        ///
        /// - Parameters:
        ///   - provider: The OAuth provider used for authentication, such as Google or Facebook.
        case oauth(_ provider: OAuthProvider)

        /// The user will be authenticated with their passkey.
        case passkey

        /// The `SignIn` will attempt to retrieve information from the active `SignUp` instance and use it to complete the sign-in process.
        ///
        /// This is useful for seamlessly transitioning a user from a sign-up attempt to a sign-in attempt.
        case transfer

        
        @MainActor
        var params: SignInCreateParams {
            switch self {
            case .identifier(let identifier, let password):
                .init(identifier: identifier, password: password)
                
            case .oauth(let oauthProvider):
                .init(strategy: oauthProvider.strategy, redirectUrl: Clerk.shared.redirectConfig.redirectUrl)
                
            case .enterpriseSSO(let emailAddress):
                .init(strategy: "enterprise_sso", identifier: emailAddress, redirectUrl: Clerk.shared.redirectConfig.redirectUrl)
                
            case .idToken(let provider, let idToken):
                .init(strategy: provider.strategy, token: idToken)
                
            case .passkey:
                .init(strategy: "passkey")
                
            case .transfer:
                .init(transfer: true)
            }
        }
    }
    
    struct SignInCreateParams: Encodable {
        var strategy: String?
        var identifier: String?
        var password: String?
        var ticket: String?
        var redirectUrl: String?
        var actionCompleteRedirectUrl: String?
        var transfer: Bool?
        var oidcPrompt: String?
        var oidcLoginHint: String?
        var token: String?
    }
    
}
