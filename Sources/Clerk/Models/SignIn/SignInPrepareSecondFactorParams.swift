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
    }

    /// A strategy for preparing the second factor verification process.
    public enum PrepareSecondFactorStrategy: Sendable {

        /// The user will receive a one-time authentication code via SMS. At least one phone number should be on file for the user.
        case phoneCode

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
            case .phoneCode:
                return .init(strategy: strategy)
            case .emailCode(let emailAddressId):
                return .init(
                    strategy: strategy,
                    emailAddressId: emailAddressId ?? signIn.identifyingSecondFactor(strategy: self)?.emailAddressId
                )
            }
        }
    }
}
