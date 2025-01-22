//
//  SignUpCreateParams.swift
//  Clerk
//
//  Created by Mike Pitre on 1/22/25.
//

import Foundation

extension SignUp {
    
    /// Parameters used to create and configure a new sign-up process.
    ///
    /// The `CreateParams` struct defines all the parameters that can be passed when initiating a sign-up process.
    /// These parameters provide flexibility to support various authentication strategies, user details, and custom configurations.
    public struct CreateParams: Encodable {
        
        /// The strategy to use for the sign-up flow.
        public var strategy: String?
        
        /// The user's first name. Only supported if name is enabled.
        public var firstName: String?
        
        /// The user's last name. Only supported if name is enabled.
        public var lastName: String?
        
        /// The user's password. Only supported if password is enabled.
        public var password: String?
        
        /// The user's email address. Only supported if email address is enabled. Keep in mind that the email address requires an extra verification process.
        public var emailAddress: String?
        
        /// The user's phone number in E.164 format. Only supported if phone number is enabled. Keep in mind that the phone number requires an extra verification process.
        public var phoneNumber: String?

        /// Required if Web3 authentication is enabled. The Web3 wallet address, made up of 0x + 40 hexadecimal characters.
        public var web3Wallet: String?
        
        /// The user's username. Only supported if usernames are enabled.
        public var username: String?
        
        /// Metadata that can be read and set from the frontend.
        ///
        /// Once the sign-up is complete, the value of this field will be automatically copied to the newly created user's unsafe metadata.
        /// One common use case for this attribute is to use it to implement custom fields that can be collected during sign-up and will automatically be attached to the created User object.
        public var unsafeMetadata: JSON?
        
        /// If strategy is set to 'oauth_{provider}' or 'enterprise_sso', this specifies full URL or path that the OAuth provider should redirect to after successful authorization on their part.
        ///
        /// If strategy is set to 'email_link', this specifies The full URL that the user will be redirected to when they visit the email link. See the custom flow for implementation details.
        public var redirectUrl: String?
        
        /// Optional if strategy is set to 'oauth_{provider}' or 'enterprise_sso'. The full URL or path that the user will be redirected to after successful authorization from the OAuth provider and Clerk sign-in.
        public var actionCompleteRedirectUrl: String?
        
        /// Required if strategy is set to 'ticket'. The ticket or token generated from the Backend API.
        public var ticket: String?
        
        /// When set to true, the SignUp will attempt to retrieve information from the active SignIn instance and use it to complete the sign-up process.
        ///
        /// This is useful when you want to seamlessly transition a user from a sign-in attempt to a sign-up attempt.
        public var transfer: Bool?
        
        /// A boolean indicating whether the user has agreed to the legal compliance documents.
        public var legalAccepted: Bool?
        
        /// Optional if strategy is set to 'oauth_{provider}' or 'enterprise_sso'. The value to pass to the OIDC prompt parameter in the generated OAuth redirect URL.
        public var oidcPrompt: String?
        
        /// Optional if strategy is set to 'oauth_<provider>' or 'enterprise_sso'. The value to pass to the OIDC login_hint parameter in the generated OAuth redirect URL.
        public var oidcLoginHint: String?
        
        /// The ID token from a provider used for authentication (e.g., SignInWithApple).
        public var token: String?
        
        public init(
            strategy: String? = nil,
            firstName: String? = nil,
            lastName: String? = nil,
            password: String? = nil,
            emailAddress: String? = nil,
            phoneNumber: String? = nil,
            web3Wallet: String? = nil,
            username: String? = nil,
            unsafeMetadata: JSON? = nil,
            redirectUrl: String? = nil,
            actionCompleteRedirectUrl: String? = nil,
            ticket: String? = nil,
            transfer: Bool? = nil,
            legalAccepted: Bool? = nil,
            oidcPrompt: String? = nil,
            oidcLoginHint: String? = nil,
            token: String? = nil
        ) {
            self.strategy = strategy
            self.firstName = firstName
            self.lastName = lastName
            self.password = password
            self.emailAddress = emailAddress
            self.phoneNumber = phoneNumber
            self.web3Wallet = web3Wallet
            self.username = username
            self.unsafeMetadata = unsafeMetadata
            self.redirectUrl = redirectUrl
            self.actionCompleteRedirectUrl = actionCompleteRedirectUrl
            self.ticket = ticket
            self.transfer = transfer
            self.legalAccepted = legalAccepted
            self.oidcPrompt = oidcPrompt
            self.oidcLoginHint = oidcLoginHint
            self.token = token
        }
    }
    
    /// Represents the various strategies for initiating a `SignUp` request.
    public enum CreateStrategy {
        
        /// Standard sign-up strategy, allowing the user to provide common details such as email, password, and personal information.
        ///
        /// - Parameters:
        ///   - emailAddress: The user's email address (optional).
        ///   - password: The user's password (optional).
        ///   - firstName: The user's first name (optional).
        ///   - lastName: The user's last name (optional).
        ///   - username: The user's username (optional).
        ///   - phoneNumber: The user's phone number (optional).
        case standard(
            emailAddress: String? = nil,
            password: String? = nil,
            firstName: String? = nil,
            lastName: String? = nil,
            username: String? = nil,
            phoneNumber: String? = nil
        )
        
        /// OAuth-based sign-up strategy, using an external provider for authentication.
        ///
        /// - Parameter provider: The OAuth provider used for authentication.
        case oauth(provider: OAuthProvider)
        
        /// Enterprise single sign-on (SSO) sign-up strategy, allowing authentication through an enterprise identity provider.
        ///
        /// - Parameter identifier: The unique identifier for the enterprise SSO user.
        case enterpriseSSO(identifier: String)
        
        /// Sign-up strategy using an ID Token, typically obtained from third-party identity providers like Apple.
        ///
        /// - Parameters:
        ///   - provider: The provider of the ID token.
        ///   - idToken: The ID token to be used for authentication.
        ///   - firstName: The user's first name (optional).
        ///   - lastName: The user's last name (optional).
        case idToken(
            provider: IDTokenProvider,
            idToken: String,
            firstName: String? = nil,
            lastName: String? = nil
        )
        
        /// Transfers an active sign-in instance to a new sign-up process.
        case transfer
        
        /// The `SignUp` will be created without any parameters.
        ///
        /// This is useful for inspecting a newly created `SignUp` object before deciding on a strategy.
        case none
        
        /// Converts the strategy into the appropriate `CreateParams` object for a `SignUp` request.
        ///
        /// This computed property maps each strategy case to its corresponding `CreateParams` object.
        /// For example:
        /// - `.standard`: Populates fields such as `firstName`, `lastName`, `emailAddress`, etc.
        /// - `.oauth`: Sets OAuth-specific fields such as `strategy` and `redirectUrl`.
        /// - `.enterpriseSSO`: Sets fields required for enterprise SSO, such as the identifier and redirect URL.
        /// - `.idToken`: Populates fields required for ID Token authentication.
        /// - `.transfer`: Sets the `transfer` field to `true`.
        ///
        /// - Returns: A `CreateParams` object containing all the necessary data for the `SignUp` request.
        @MainActor
        var params: CreateParams {
            switch self {
            case .standard(let value):
                .init(
                    firstName: value.firstName,
                    lastName: value.lastName,
                    password: value.password,
                    emailAddress: value.emailAddress,
                    phoneNumber: value.phoneNumber,
                    username: value.username
                )
            case .oauth(let provider):
                .init(
                    strategy: provider.strategy,
                    redirectUrl: Clerk.shared.redirectConfig.redirectUrl,
                    actionCompleteRedirectUrl: Clerk.shared.redirectConfig.redirectUrl
                )
            case .enterpriseSSO(let identifier):
                .init(
                    strategy: "enterprise_sso",
                    emailAddress: identifier,
                    redirectUrl: Clerk.shared.redirectConfig.redirectUrl
                )
            case .idToken(let value):
                .init(
                    strategy: value.provider.strategy,
                    firstName: value.firstName,
                    lastName: value.lastName,
                    token: value.idToken
                )
            case .transfer:
                .init(transfer: true)
            case .none:
                .init()
            }
        }
    }
    
    /// UpdateParams is a mirror of CreateParams with the same fields and types.
    public typealias UpdateParams = CreateParams
    
}
