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
struct SignInFactor: Decodable {
    init(
        strategy: VerificationStrategy,
        safeIdentifier: String? = nil,
        emailAddressId: String? = nil
    ) {
        self.strategy = strategy.stringValue
        self.safeIdentifier = safeIdentifier
        self.emailAddressId = emailAddressId
    }
    
    let strategy: String
    let safeIdentifier: String?
    let emailAddressId: String?
}
