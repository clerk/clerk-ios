//
//  SignInFactor.swift
//
//
//  Created by Mike Pitre on 2/9/24.
//

import Foundation

public struct SignInFactor: Codable, Equatable, Hashable {
    public let strategy: String
    public let safeIdentifier: String?
    public let emailAddressId: String?
    public let phoneNumberId: String?
    public let web3WalletId: String?
    public let primary: Bool?
    public let `default`: Bool?
    
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
}

extension SignInFactor {
    
    var strategyEnum: Strategy? {
        Strategy(stringValue: strategy)
    }
    
    var prepareFirstFactorStrategy: SignIn.PrepareFirstFactorStrategy? {
        switch strategyEnum {
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
    
    var prepareSecondFactorStrategy: SignIn.PrepareSecondFactorStrategy? {
        switch strategyEnum {
        case .phoneCode:
            return .phoneCode
        default:
            return nil
        }
    }
    
    var actionText: String? {
        switch strategyEnum {
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
        case .totp:
            return "Use your authenticator app"
        case .backupCode:
            return "Use a backup code"
        default:
            return nil
        }
    }
    
    var sortOrderPasswordPreferred: Int {
        switch self.strategyEnum {
        case .password: 0
        case .emailCode: 1
        case .phoneCode: 2
        case .emailLink: 3
        default: 100
        }
    }
    
    var sortOrderOTPPreferred: Int {
        switch self.strategyEnum {
        case .emailCode: 0
        case .phoneCode: 1
        case .emailLink: 2
        case .password: 3
        default: 100
        }
    }
    
}
