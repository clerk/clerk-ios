//
//  Verification.swift
//  
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/**
 The verification strategy to validate the user's sign-up request. The following strategies are supported:
 - phone_code: Send an SMS with a unique token to input.
 - email_code: Send an email with a unique token to input.
 - email_link: Send an email with a link which validates sign-up
 - saml: Authenticate against SAML. Experimental
 - oauth_*: Authenticate against various OAuth providers.
 - web3_*_signature: Authenticate against Web3 signatures.
 */
public enum VerificationStrategy: Encodable {
    case phoneCode
    case emailCode
    case emailLink
    case saml
    case oauth(String)
    case web3(String)
    
    // When sending requests, if you need to send a verification strategy in the body
    // do not pass it in its encoded form, manually create the body so you can use the `stringValue`
    // enums with associated values can not have rawValues
    var stringValue: String {
        switch self {
        case .phoneCode:
            return "phone_code"
        case .emailCode:
            return "email_code"
        case .emailLink:
            return "email_link"
        case .saml:
            return "saml"
        case .oauth(let provider):
            return "oauth_\(provider)"
        case .web3(let signature):
            return "web3_\(signature)_signature"
        }
    }
}
