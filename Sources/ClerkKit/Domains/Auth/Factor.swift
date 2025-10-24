//
//  SignInFactor.swift
//
//
//  Created by Mike Pitre on 2/9/24.
//

import Foundation

/// The Factor type represents the factor verification strategy that can be used in the sign-in process.
public struct Factor: Codable, Equatable, Hashable, Sendable {

    /// The strategy of the factor.
    public let strategy: String

    /// The ID of the email address that a code or link will be sent to.
    public let emailAddressId: String?

    /// The ID of the phone number that a code will be sent to.
    public let phoneNumberId: String?

    /// The ID of the Web3 wallet that will be used to sign a message.
    public let web3WalletId: String?

    /// The safe identifier of the factor.
    public let safeIdentifier: String?

    /// Whether the factor is the primary factor.
    public let primary: Bool?

    public init(
        strategy: String,
        emailAddressId: String? = nil,
        phoneNumberId: String? = nil,
        web3WalletId: String? = nil,
        safeIdentifier: String? = nil,
        primary: Bool? = nil
    ) {
        self.strategy = strategy
        self.emailAddressId = emailAddressId
        self.phoneNumberId = phoneNumberId
        self.web3WalletId = web3WalletId
        self.safeIdentifier = safeIdentifier
        self.primary = primary
    }
}

extension Factor {

    package static var mockEmailCode: Factor {
        Factor(strategy: "email_code")
    }

    package static var mockPhoneCode: Factor {
        Factor(strategy: "phone_code")
    }

    package static var mockGoogle: Factor {
        Factor(strategy: "oauth_google")
    }

    package static var mockApple: Factor {
        Factor(strategy: "oauth_apple")
    }

    package static var mockPassword: Factor {
        Factor(strategy: "password")
    }

    package static var mockPasskey: Factor {
        Factor(strategy: "passkey")
    }

    package static var mockResetPasswordEmailCode: Factor {
        Factor(strategy: "reset_password_email_code")
    }

    package static var mockResetPasswordPhoneCode: Factor {
        Factor(strategy: "reset_password_phone_code")
    }

    package static var mockTotp: Factor {
        Factor(strategy: "totp")
    }

    package static var mockBackupCode: Factor {
        Factor(strategy: "backup_code")
    }

}
