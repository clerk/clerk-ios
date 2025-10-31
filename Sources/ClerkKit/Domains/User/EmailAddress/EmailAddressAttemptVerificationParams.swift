//
//  EmailAddressAttemptVerificationParams.swift
//  Clerk
//
//  Created by Mike Pitre on 1/24/25.
//

import SwiftUI

extension EmailAddress {

    /// Represents the strategy for attempting email address verification.
    ///
    /// Use this enum to specify the method of verification when calling the ``EmailAddress/attemptVerification(strategy:)`` function.
    public enum AttemptStrategy: Sendable {

        /// The strategy for email verification using a one-time code.
        ///
        /// - Parameter code: The one-time code that was sent to the user's email address when calling ``EmailAddress/prepareVerification(strategy:)``.
        case emailCode(code: String)

        /// The request body that will be sent with the verification attempt.
        ///
        /// This computed property returns the appropriate `RequestBody` struct based on the selected strategy.
        var requestBody: RequestBody {
            switch self {
            case .emailCode(let code):
                return .init(code: code)
            }
        }

        /// A struct that represents the request body for attempting email address verification.
        struct RequestBody: Encodable {
            /// The one-time code that the user enters to verify their email address.
            let code: String
        }
    }
}
