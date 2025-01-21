//
//  SignInPrepareFirstFactor.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

import Foundation

extension SignIn {
    
    /// Represents the strategies for beginning the first factor verification process.
    ///
    /// The `PrepareFirstFactorStrategy` enum defines the different methods available for verifying the first factor in the sign-in process. Each strategy corresponds to a specific type of authentication.
    public enum PrepareFirstFactorStrategy {
        /// The user will receive a one-time authentication code via email.
        /// - Parameters:
        ///   - emailAddressId: ID to specify a particular email address.
        case emailCode(emailAddressId: String)
        
        /// The user will receive a one-time authentication code via SMS.
        /// - Parameters:
        ///   - phoneNumberId: ID to specify a particular phone number.
        case phoneCode(phoneNumberId: String)
        
        /// The user will be authenticated either through SAML or OIDC, depending on the configuration of their enterprise SSO account.
        case enterpriseSSO
        
        /// The verification will attempt to be completed using the user's passkey.
        case passkey
        
        /// Used during a password reset flow. The user will receive a one-time code via email.
        /// - Parameters:
        ///   - emailAddressId: ID to specify a particular email address.
        case resetPasswordEmailCode(emailAddressId: String)
        
        /// Used during a password reset flow. The user will receive a one-time code via SMS.
        /// - Parameters:
        ///   - phoneNumberId: ID to specify a particular phone number.
        case resetPasswordPhoneCode(phoneNumberId: String)
        
        @MainActor
        var params: PrepareFirstFactorParams {
            switch self {
            case .emailCode(let emailAddressId):
                return .init(strategy: "email_code", emailAddressId: emailAddressId)
            case .phoneCode(let phoneNumberId):
                return .init(strategy: "phone_code", phoneNumberId: phoneNumberId)
            case .passkey:
                return .init(strategy: "passkey")
            case .enterpriseSSO:
                return .init(strategy: "enterprise_sso", redirectUrl: Clerk.shared.redirectConfig.redirectUrl)
            case .resetPasswordEmailCode(let emailAddressId):
                return .init(strategy: "reset_password_email_code", emailAddressId: emailAddressId)
            case .resetPasswordPhoneCode(let phoneNumberId):
                return .init(strategy: "reset_password_phone_code", phoneNumberId: phoneNumberId)
            }
        }
    }
    
    public struct PrepareFirstFactorParams: Encodable {
        /// The strategy value depends on the object's identifier value. Each authentication identifier supports different verification strategies.
        public let strategy: String
        
        /// Unique identifier for the user's email address that will receive an email message with the one-time authentication code. This parameter will work only when the `email_code` strategy is specified.
        public var emailAddressId: String?
        
        /// Unique identifier for the user's phone number that will receive an SMS message with the one-time authentication code. This parameter will work only when the `phone_code` strategy is specified.
        public var phoneNumberId: String?
        
        /// The URL that the OAuth provider should redirect to, on successful authorization on their part. This parameter is required only if you set the strategy param to an OAuth strategy like `oauth_<provider>`.
        public var redirectUrl: String?
        
        /// The URL that the user will be redirected to, after successful authorization from the OAuth provider and Clerk sign in. This parameter is required only if you set the strategy param to an OAuth strategy like `oauth_<provider>`.
        public var actionCompleteRedirectUrl: String?
    }
    
}
