//
//  SignInFactor.swift
//
//
//  Created by Mike Pitre on 2/9/24.
//

import Foundation

/// Each factor contains information about the verification strategy that can be used.
public struct SignInFactor: Codable, Equatable, Hashable, Sendable {
    /// The strategy value depends on the object's identifier value. Each authentication identifier supports different verification strategies.
    public let strategy: String
        
    /// Unique identifier for the user's email address that will receive an email message with the one-time authentication code. This parameter will work only when the email_code strategy is specified.
    public let emailAddressId: String?
    
    /// Unique identifier for the user's phone number that will receive an SMS message with the one-time authentication code. This parameter will work only when the phone_code strategy is specified.
    public let phoneNumberId: String?
    
    /// Unique identifier for the user's web3 wallet public address. This parameter will work only when the web3_metamask_signature strategy is specified.
    public let web3WalletId: String?
    
    let safeIdentifier: String?
    let primary: Bool?
    let `default`: Bool?
}

extension SignInFactor {
    
    public var strategyEnum: Strategy? {
        Strategy(stringValue: strategy)
    }
    
    var prepareFirstFactorStrategy: SignIn.PrepareFirstFactorStrategy? {
        switch strategyEnum {
        case .phoneCode:
            return .phoneCode
        case .emailCode:
            return .emailCode
//        case .emailLink:
//            return .emailLink
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
//        case .emailLink:
//            guard let safeIdentifier else { return nil }
//            return "Email link to \(safeIdentifier)"
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
//        case .emailLink: 3
        default: 100
        }
    }
    
    var sortOrderOTPPreferred: Int {
        switch self.strategyEnum {
        case .emailCode: 0
        case .phoneCode: 1
//        case .emailLink: 2
        case .password: 3
        default: 100
        }
    }
    
}
