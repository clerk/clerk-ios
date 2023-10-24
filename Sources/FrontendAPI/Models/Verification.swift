//
//  Verification.swift
//  
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import RegexBuilder

/// The state of the verification process of a sign-in or sign-up attempt.
public struct Verification: Decodable {
    
    /// The state of the verification.
    let status: Status?
    
    /// The strategy pertaining to the parent sign-up or sign-in attempt.
    let strategy: String?
    
    /// The number of attempts related to the verification.
    let attempts: Int?
    
    /// The time the verification will expire at.
    let expireAt: Date?
    
    /// The last error the verification attempt ran into.
    let error: ClerkAPIError?
    
    /// The redirect URL for an external verification.
    public var externalVerificationRedirectUrl: String?
    
    enum Status: String, Decodable {
        case unverified
        case verified
        case transferable
        case failed
        case expired
    }
}

extension Verification {
    public var verificationStrategy: VerificationStrategy? {
        guard let strategy else { return nil }
        return .init(stringValue: strategy)
    }
}

/**
 The verification strategy to validate the user's sign-up request. The following strategies are supported:
 - phone_code: Send an SMS with a unique token to input.
 - email_code: Send an email with a unique token to input.
 - email_link: Send an email with a link which validates sign-up
 - saml: Authenticate against SAML. Experimental
 - oauth_*: Authenticate against various OAuth providers.
 - web3_*_signature: Authenticate against Web3 signatures.
 */
public enum VerificationStrategy: Hashable {
    case password
    case phoneCode
    case emailCode
    case emailLink
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
        }
    }
    
    public init?(stringValue: String) {
        switch stringValue {
        case VerificationStrategy.password.stringValue:
            self = .password
        case VerificationStrategy.phoneCode.stringValue:
            self = .phoneCode
        case VerificationStrategy.emailCode.stringValue:
            self = .emailCode
        case VerificationStrategy.emailLink.stringValue:
            self = .emailLink
        case VerificationStrategy.saml.stringValue:
            self = .saml
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
