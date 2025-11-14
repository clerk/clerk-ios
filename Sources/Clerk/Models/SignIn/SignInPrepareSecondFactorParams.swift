//
//  SignInPrepareSecondFactor.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

import Foundation

extension SignIn {

    /// A parameter object for preparing the second factor verification.
    struct PrepareSecondFactorParams: Encodable {
        /// The strategy used for second factor verification..
        let strategy: String

        /// Unique identifier for the user's email address that will receive an email message with the one-time authentication code. This parameter will work only when the `email_code` strategy is specified.
        var emailAddressId: String?

        /// Unique identifier for the user's phone number that will receive an SMS message with the one-time authentication code. This parameter will work only when the `phone_code` strategy is specified.
        var phoneNumberId: String?
    }

    /// A strategy for preparing the second factor verification process.
    public enum PrepareSecondFactorStrategy: Sendable {

        /// The user will receive a one-time authentication code via SMS. At least one phone number should be on file for the user.
        /// - Parameters:
        ///   - phoneNumberId: ID to specify a particular phone number.
        case phoneCode(phoneNumberId: String? = nil)

        /// The user will receive a one-time authentication code via email. At least one email address should be on file for the user.
        /// - Parameters:
        ///   - emailAddressId: ID to specify a particular email address.
        case emailCode(emailAddressId: String? = nil)

        var strategy: String {
            switch self {
            case .phoneCode:
                "phone_code"
            case .emailCode:
                "email_code"
            }
        }

        @MainActor
        func params(signIn: SignIn) -> PrepareSecondFactorParams {
            switch self {
            case .phoneCode(let phoneNumberId):
                return .init(
                    strategy: strategy,
                    phoneNumberId: phoneNumberId ?? signIn.identifyingSecondFactor(strategy: self)?.phoneNumberId
                )
            case .emailCode(let emailAddressId):
                return .init(
                    strategy: strategy,
                    emailAddressId: emailAddressId ?? signIn.identifyingSecondFactor(strategy: self)?.emailAddressId
                )
            }
        }
    }
}
