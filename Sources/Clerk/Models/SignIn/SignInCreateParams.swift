//
//  SignInCreate.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

import Foundation

extension SignIn {
  
  /// Represents the parameters required to initiate a sign-in flow.
  ///
  /// This structure encapsulates the various options for initiating a sign-in, including the authentication strategy, user identifier, optional passwords, and additional settings for redirect URLs or OAuth-specific parameters.
  struct SignInCreateParams: Encodable {
    
    /// The first factor verification strategy to use in the sign-in flow.
    ///
    /// Depends on the `identifier` value, and each authentication identifier supports different verification strategies.
    var strategy: String?
    
    /// The authentication identifier for the sign-in.
    ///
    /// This can be the value of the user's email address, phone number, username, or Web3 wallet address.
    var identifier: String?
    
    /// The user's password.
    ///
    /// Only supported if the `strategy` is set to `password` and password authentication is enabled.
    var password: String?
    
    /// A ticket or token generated from the Backend API.
    ///
    /// Required if the `strategy` is set to `ticket`.
    var ticket: String?
    
    /// The ID token from a provider used for authentication (e.g., SignInWithApple).
    ///
    /// Required is strategy is set to `oauth_token_<provider>`
    var token: String?
    
    /// The URL to redirect to after successful authorization from the OAuth provider or during certain email-based sign-in flows.
    ///
    /// - If `strategy` is `oauth_<provider>` or `enterprise_sso`, this specifies the full URL or path the OAuth provider should redirect to after successful authorization.
    /// - If `strategy` is `'email_link'`, this specifies the URL that the user will be redirected to when they visit the email link.
    var redirectUrl: String?
    
    /// Indicates whether the sign-in will attempt to retrieve information from the active sign-up instance to complete the sign-in process.
    ///
    /// Useful when transitioning seamlessly from a sign-up attempt to a sign-in attempt.
    var transfer: Bool?
    
    /// The value to pass to the OIDC `prompt` parameter in the generated OAuth redirect URL.
    ///
    /// Optional if `strategy` is `'oauth_<provider>'` or `'enterprise_sso'`.
    var oidcPrompt: String?
    
    /// The value to pass to the OIDC `login_hint` parameter in the generated OAuth redirect URL.
    ///
    /// Optional if `strategy` is `'oauth_<provider>'` or `'enterprise_sso'`.
    var oidcLoginHint: String?
  }
  
  
  /// Represents the various strategies for creating a `SignIn` request.
  public enum CreateStrategy: Sendable {
    
    /// The user will be authenticated either through SAML or OIDC depending on the configuration of their enterprise SSO account.
    ///
    /// - Parameters:
    ///   - emailAddress: The email address associated with the user's enterprise SSO account.
    case enterpriseSSO(identifier: String, redirectUrl: String? = nil)
    
    /// The user will be authenicated using an ID Token, typically obtained from third-party identity providers like Apple.
    ///
    /// - Parameters:
    ///   - provider: The ID token provider used for authentication (e.g., SignInWithApple).
    ///   - idToken: The ID token issued by the provider for authentication.
    case idToken(provider: IDTokenProvider, idToken: String)
    
    /// The user will be authenticated with the provided identifier.
    ///
    /// - Parameters:
    ///   - identifier: The authentication identifier for the sign-in. This can be the user's email address, phone number, username, or Web3 wallet address.
    ///   - password: The user's password.
    case identifier(_ identifier: String, password: String? = nil, strategy: String? = nil)
    
    /// The user will be authenticated with their social connection account.
    ///
    /// - Parameters:
    ///   - provider: The OAuth provider used for authentication, such as Google or Facebook.
    case oauth(provider: OAuthProvider, redirectUrl: String? = nil)
    
    /// The user will be authenticated with their passkey.
    case passkey
    
    /// The user will be authenticated via the ticket or token generated from the Backend API.
    case ticket(String)
    
    /// The `SignIn` will attempt to retrieve information from the active `SignUp` instance and use it to complete the sign-in process.
    ///
    /// This is useful for seamlessly transitioning a user from a sign-up attempt to a sign-in attempt.
    case transfer
    
    /// The `SignIn` will be created without any parameters.
    ///
    /// This is useful for inspecting a newly created `SignIn` object before deciding on a strategy.
    case none
    
    
    var params: SignInCreateParams {
      switch self {
      case .identifier(let identifier, let password, let strategy):
          .init(strategy: strategy, identifier: identifier, password: password)
        
      case .oauth(let oauthProvider, let redirectUrl):
          .init(strategy: oauthProvider.strategy, redirectUrl: redirectUrl ?? RedirectConfigDefaults.redirectUrl)
        
      case .enterpriseSSO(let emailAddress, let redirectUrl):
          .init(strategy: "enterprise_sso", identifier: emailAddress, redirectUrl: redirectUrl ?? RedirectConfigDefaults.redirectUrl)
        
      case .idToken(let provider, let idToken):
          .init(strategy: provider.strategy, token: idToken)
        
      case .passkey:
          .init(strategy: "passkey")
        
      case .ticket(let ticket):
          .init(strategy: "ticket", ticket: ticket)
        
      case .transfer:
          .init(transfer: true)
        
      case .none:
          .init()
      }
    }
  }
  
}
