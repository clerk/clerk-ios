//
//  Strategy.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/// Represents the various strategies for authenticating.
public enum Strategy: Codable, Equatable {
    case passkey
    case password
    case phoneCode
    case emailCode
    case emailLink
    case ticket
    case totp
    case backupCode
    case resetPasswordPhoneCode
    case resetPasswordEmailCode
    case enterpriseSSO
    case oauth(provider: OAuthProvider)
    case unknown
    
    public var stringValue: String {
        switch self {
        case .passkey:
            "passkey"
        case .password:
            "password"
        case .phoneCode:
            "phone_code"
        case .emailCode:
            "email_code"
        case .emailLink:
            "email_link"
        case .ticket:
            "ticket"
        case .totp:
            "totp"
        case .backupCode:
            "backup_code"
        case .resetPasswordPhoneCode:
            "reset_password_phone_code"
        case .resetPasswordEmailCode:
            "reset_password_email_code"
        case .enterpriseSSO:
            "enterprise_sso"
        case .oauth(let provider):
            provider.strategy
        case .unknown:
            ""
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let strategyString = try container.decode(String.self)
        
        switch strategyString {
        case Strategy.passkey.stringValue:
            self = .passkey
        case Strategy.password.stringValue:
            self = .password
        case Strategy.phoneCode.stringValue:
            self = .phoneCode
        case Strategy.emailCode.stringValue:
            self = .emailCode
        case Strategy.emailLink.stringValue:
            self = .emailLink
        case Strategy.ticket.stringValue:
            self = .ticket
        case Strategy.totp.stringValue:
            self = .totp
        case Strategy.backupCode.stringValue:
            self = .backupCode
        case Strategy.resetPasswordPhoneCode.stringValue:
            self = .resetPasswordPhoneCode
        case Strategy.resetPasswordEmailCode.stringValue:
            self = .resetPasswordEmailCode
        case Strategy.enterpriseSSO.stringValue:
            self = .enterpriseSSO
        case let strategyString where strategyString.starts(with: "oauth_"):
            self = .oauth(provider: OAuthProvider(strategy: strategyString))
        default:
            self = .unknown
        }
    }
}

extension Strategy {
    
    var isResetStrategy: Bool {
        [.resetPasswordEmailCode, .resetPasswordPhoneCode].contains(self)
    }
    
}
