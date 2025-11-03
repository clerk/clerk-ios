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
    case oauth(provider: OAuthProvider, redirectUrl: String? = nil)

    /// The user will be authenticated with their enterprise SSO account.
    case enterpriseSSO(identifier: String, redirectUrl: String? = nil)

    @MainActor
    var signInStrategy: SignIn.CreateStrategy {
      switch self {
      case .oauth(let provider, let redirectUrl):
        return .oauth(
          provider: provider,
          redirectUrl: redirectUrl ?? Clerk.shared.options.redirectConfig.redirectUrl
        )
      case .enterpriseSSO(let identifier, let redirectUrl):
        return .enterpriseSSO(
          identifier: identifier,
          redirectUrl: redirectUrl ?? Clerk.shared.options.redirectConfig.redirectUrl
        )
      }
    }
  }

}
