//
//  Strategy.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import RegexBuilder

/// The strategy to validate the user's request.
public enum Strategy: Codable, Equatable {
    case password
    case phoneCode
    case emailCode
    case ticket
    case totp
    case backupCode
    case resetPasswordPhoneCode
    case resetPasswordEmailCode
    case saml
    case oauth(_ provider: OAuthProvider)
    
    var stringValue: String {
        switch self {
        case .password:
            return "password"
        case .phoneCode:
            return "phone_code"
        case .emailCode:
            return "email_code"
        case .saml:
            return "saml"
        case .oauth(let provider):
            return provider.providerData.strategy
        case .ticket:
            return "ticket"
        case .totp:
            return "totp"
        case .backupCode:
            return "backup_code"
        case .resetPasswordPhoneCode:
            return "reset_password_phone_code"
        case .resetPasswordEmailCode:
            return "reset_password_email_code"
        }
    }
    
    init?(stringValue: String) {
        switch stringValue {
        case Strategy.password.stringValue:
            self = .password
        case Strategy.phoneCode.stringValue:
            self = .phoneCode
        case Strategy.emailCode.stringValue:
            self = .emailCode
        case Strategy.saml.stringValue:
            self = .saml
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
        case let value where value.hasPrefix("oauth_"):
            let regex = Regex {
                "oauth_"
                
                Capture {
                    OneOrMore(.any)
                }
            }
            
            if
                let strategy = value.firstMatch(of: regex)?.output.0,
                let provider = OAuthProvider(strategy: String(strategy))
            {
                self = .oauth(provider)
            } else {
                return nil
            }
            
        default:
            return nil
        }
    }
}

extension Strategy {
    
    var isResetStrategy: Bool {
        [.resetPasswordEmailCode, .resetPasswordPhoneCode].contains(self)
    }
    
    var icon: String? {
        switch self {
        case .password:
            return "lock.fill"
        case .phoneCode:
            return "text.bubble.fill"
        case .emailCode:
            return "envelope.fill"
        default:
            return nil
        }
    }
    
    var signInPrepareStrategy: SignIn.PrepareFirstFactorStrategy? {
        switch self {
        case .phoneCode:
            return .phoneCode
        case .emailCode:
            return .emailCode
        case .saml:
            return .saml
        default:
            return nil
        }
    }
    
}
