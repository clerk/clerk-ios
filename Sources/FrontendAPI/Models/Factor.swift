//
//  SignInFactor.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

import Foundation

/**
 Each factor contains information about the verification strategy that can be used.
 For example:
 email_code for email addresses
 phone_code for phone numbers
 As well as the identifier that the factor refers to.
 */
public struct Factor: Codable, Hashable {
    init(
        strategy: Strategy,
        safeIdentifier: String? = nil,
        emailAddressId: String? = nil,
        phoneNumberId: String? = nil,
        web3WalletId: String? = nil,
        primary: Bool? = nil,
        `default`: Bool? = nil
    ) {
        self.strategy = strategy.stringValue
        self.safeIdentifier = safeIdentifier
        self.emailAddressId = emailAddressId
        self.phoneNumberId = phoneNumberId
        self.web3WalletId = web3WalletId
        self.primary = primary
        self.default = `default`
    }
    
    public let strategy: String
    public let safeIdentifier: String?
    public let emailAddressId: String?
    public let phoneNumberId: String?
    public let web3WalletId: String?
    public let primary: Bool?
    public let `default`: Bool?
}

extension Factor {
    
    public var verificationStrategy: Strategy? {
        Strategy(stringValue: strategy)
    }
    
    var isResetStrategy: Bool {
        [
            Strategy.resetPasswordEmailCode,
            Strategy.resetPasswordPhoneCode
        ]
        .contains(verificationStrategy)
    }
    
    public var actionText: String? {
        switch verificationStrategy {
        case .phoneCode:
            guard let safeIdentifier else { return nil }
            return "Send SMS code to \(safeIdentifier)"
        case .emailCode:
            guard let safeIdentifier else { return nil }
            return "Email code to \(safeIdentifier)"
        case .emailLink:
            guard let safeIdentifier else { return nil }
            return "Email link to \(safeIdentifier)"
        case .password:
            return "Sign in with your password"
        default:
            return nil
        }
    }
    
    public var prepareFirstFactorStrategy: SignIn.PrepareStrategy? {
        switch verificationStrategy {
        case .phoneCode:
            return .phoneCode
        case .emailCode:
            return .emailCode
        case .emailLink:
            return .emailLink
        default:
            return nil
        }
    }
    
}
