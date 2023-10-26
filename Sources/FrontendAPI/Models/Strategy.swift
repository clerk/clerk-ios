//
//  Strategy.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import RegexBuilder

/**
 The strategy to validate the user's request. The following strategies are supported:
 - phone_code: Send an SMS with a unique token to input.
 - email_code: Send an email with a unique token to input.
 - email_link: Send an email with a link which validates sign-up
 - saml: Authenticate against SAML. Experimental
 - `oauth_{provider}`: Authenticate against various OAuth providers.
 - `web3_{signature}_signature`: Authenticate against Web3 signatures.
 */
public enum Strategy: Hashable {
    case password
    case phoneCode
    case emailCode
    case emailLink
    case ticket
    case totp
    case backupCode
    case resetPasswordPhoneCode
    case resetPasswordEmailCode
    case saml
    case oauth(_ provider: OAuthProvider)
    case web3(_ signature: String)
    
    public var stringValue: String {
        switch self {
        case .password:
            return "password"
        case .phoneCode:
            return "phone_code"
        case .emailCode:
            return "email_code"
        case .emailLink:
            return "email_link"
        case .saml:
            return "saml"
        case .oauth(let provider):
            return provider.data.strategy
        case .web3(let signature):
            return "web3_\(signature)_signature"
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
    
    public init?(stringValue: String) {
        switch stringValue {
        case Strategy.password.stringValue:
            self = .password
        case Strategy.phoneCode.stringValue:
            self = .phoneCode
        case Strategy.emailCode.stringValue:
            self = .emailCode
        case Strategy.emailLink.stringValue:
            self = .emailLink
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
                let strategy = value.firstMatch(of: regex)?.output.1,
                let provider = OAuthProvider(strategy: String(strategy))
            {
                self = .oauth(provider)
            } else {
                return nil
            }
            
        case let value where value.hasPrefix("web3_"):
            let regex = Regex {
                "web3_"
                
                Capture {
                    OneOrMore(.any)
                }
                
                "_signature"
            }
            
            if let signature = value.firstMatch(of: regex)?.output.1 {
                self = .web3(String(signature))
            } else {
                return nil
            }
            
        default:
            return nil
        }
    }
}
