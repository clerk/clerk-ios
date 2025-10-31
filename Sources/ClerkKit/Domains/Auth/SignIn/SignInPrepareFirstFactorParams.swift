//
//  SignInPrepareFirstFactor.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

import Foundation

extension SignIn {

    /// A parameter object for preparing the first factor verification.
    struct PrepareFirstFactorParams: Encodable, Sendable {
        /// The strategy value depends on the object's identifier value. Each authentication identifier supports different verification strategies.
        let strategy: String

        /// Unique identifier for the user's email address that will receive an email message with the one-time authentication code. This parameter will work only when the `email_code` strategy is specified.
        var emailAddressId: String?

        /// Unique identifier for the user's phone number that will receive an SMS message with the one-time authentication code. This parameter will work only when the `phone_code` strategy is specified.
        var phoneNumberId: String?

        /// The URL that the OAuth provider should redirect to, on successful authorization on their part. This parameter is required only if you set the strategy param to an OAuth strategy like `oauth_<provider>`.
        var redirectUrl: String?
    }

    /// Represents the strategies for beginning the first factor verification process.
    ///
    /// The `PrepareFirstFactorStrategy` enum defines the different methods available for verifying the first factor in the sign-in process. Each strategy corresponds to a specific type of authentication.
    public enum PrepareFirstFactorStrategy: Sendable {

        /// The user will receive a one-time authentication code via email.
        /// - Parameters:
        ///   - emailAddressId: ID to specify a particular email address.
        case emailCode(emailAddressId: String? = nil)

        /// The user will receive a one-time authentication code via SMS.
        /// - Parameters:
        ///   - phoneNumberId: ID to specify a particular phone number.
        case phoneCode(phoneNumberId: String? = nil)

        /// The user will be authenticated with their social connection account.
        case oauth(provider: OAuthProvider, redirectUrl: String? = nil)

        /// The user will be authenticated either through SAML or OIDC, depending on the configuration of their enterprise SSO account.
        case enterpriseSSO(redirectUrl: String? = nil)

        /// The verification will attempt to be completed using the user's passkey.
        case passkey

        /// Used during a password reset flow. The user will receive a one-time code via email.
        /// - Parameters:
        ///   - emailAddressId: ID to specify a particular email address.
        case resetPasswordEmailCode(emailAddressId: String? = nil)

        /// Used during a password reset flow. The user will receive a one-time code via SMS.
        /// - Parameters:
        ///   - phoneNumberId: ID to specify a particular phone number.
        case resetPasswordPhoneCode(phoneNumberId: String? = nil)

        var strategy: String {
            switch self {
            case .emailCode:
                "email_code"
            case .phoneCode:
                "phone_code"
            case .oauth(let provider, _):
                provider.strategy
            case .enterpriseSSO:
                "enterprise_sso"
            case .passkey:
                "passkey"
            case .resetPasswordEmailCode:
                "reset_password_email_code"
            case .resetPasswordPhoneCode:
                "reset_password_phone_code"
            }
        }

        @MainActor
        func params(signIn: SignIn) -> PrepareFirstFactorParams {
            switch self {

            case .emailCode(let emailAddressId):
                return .init(
                    strategy: strategy,
                    emailAddressId: emailAddressId ?? signIn.identifyingFirstFactor(strategy: self)?.emailAddressId
                )

            case .phoneCode(let phoneNumberId):
                return .init(
                    strategy: strategy,
                    phoneNumberId: phoneNumberId ?? signIn.identifyingFirstFactor(strategy: self)?.phoneNumberId
                )

            case .oauth(let provider, let redirectUrl):
                return .init(
                    strategy: provider.strategy,
                    redirectUrl: redirectUrl ?? Clerk.shared.options.redirectConfig.redirectUrl
                )

            case .passkey:
                return .init(strategy: strategy)

            case .enterpriseSSO(let redirectUrl):
                return .init(
                    strategy: strategy,
                    redirectUrl: redirectUrl ?? Clerk.shared.options.redirectConfig.redirectUrl
                )

            case .resetPasswordEmailCode(let emailAddressId):
                return .init(
                    strategy: strategy,
                    emailAddressId: emailAddressId ?? signIn.identifyingFirstFactor(strategy: self)?.emailAddressId
                )

            case .resetPasswordPhoneCode(let phoneNumberId):
                return .init(
                    strategy: strategy,
                    phoneNumberId: phoneNumberId ?? signIn.identifyingFirstFactor(strategy: self)?.phoneNumberId
                )
            }
        }
    }
}
