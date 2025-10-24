//
//  File.swift
//  Clerk
//
//  Created by Mike Pitre on 1/22/25.
//

import Foundation

extension SignUp {

    /// Defines the strategies for attempting verification during the sign-up process.
    public enum AttemptStrategy: Sendable {
        /// Attempts verification using a code sent to the user's email address.
        /// - Parameter code: The one-time code sent to the user's email address.
        case emailCode(code: String)

        /// Attempts verification using a code sent to the user's phone number.
        /// - Parameter code: The one-time code sent to the user's phone number.
        case phoneCode(code: String)

        /// Converts the selected strategy into `AttemptVerificationParams` for the API request.
        var params: AttemptVerificationParams {
            switch self {
            case .emailCode(let code):
                return .init(strategy: "email_code", code: code)
            case .phoneCode(let code):
                return .init(strategy: "phone_code", code: code)
            }
        }
    }

    /// Parameters used for the verification attempt during the sign-up process.
    public struct AttemptVerificationParams: Encodable, Sendable {
        /// The strategy used for verification (e.g., `email_code` or `phone_code`).
        public let strategy: String

        /// The verification code provided by the user.
        public let code: String
    }

}
