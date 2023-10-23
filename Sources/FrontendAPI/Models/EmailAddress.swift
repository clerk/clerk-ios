//
//  EmailAddress.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import Foundation

/**
 The EmailAddress object is a model around an email address. Email addresses are used to provide identification for users.

 Email addresses must be verified to ensure that they can be assigned to their rightful owners. The EmailAddress object holds all necessary state around the verification process.

 The verification process always starts with the EmailAddress.prepareVerification() method, which will send a one-time verification code via an email message. The second and final step involves an attempt to complete the verification by calling the EmailAddress.attemptVerification() method, passing the one-time code as a parameter.

 Finally, email addresses can be linked to other identifications.
 */
public struct EmailAddress: Decodable {
    /// A unique identifier for this email address.
    let id: String
    
    /// The value of this email address.
    let emailAddress: String
    
    ///
    let reserved: Bool
    
    /// An object holding information on the verification of this email address.
    let verification: Verification
    
    /// An array of objects containing information about any identifications that might be linked to this email address.
    let linkedTo: [JSON]?
}
