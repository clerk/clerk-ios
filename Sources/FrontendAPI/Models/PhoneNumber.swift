//
//  PhoneNumber.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import Foundation

/**
 The PhoneNumber object describes a phone number. Phone numbers can be used as a proof of identification for users, or simply as a means of contacting users.

 Phone numbers must be verified to ensure that they can be assigned to their rightful owners. The PhoneNumber object holds all the necessary state around the verification process.

 The verification process always starts with the PhoneNumber.prepareVerification() method, which will send a one-time verification code via an SMS message. The second and final step involves an attempt to complete the verification by calling the PhoneNumber.attemptVerification() method, passing the one-time code as a parameter.

 Finally, phone numbers are used as part of multi-factor authentication. Users receive an SMS message with a one-time code that they need to provide as an extra verification step.
 */
struct PhoneNumber: Decodable {
    /// A unique identifier for this phone number.
    let id: String
    /// The value of this phone number, in E.164 format.
    let phoneNumber: String
    /// Set to true if this phone number is reserved for multi-factor authentication (2FA). Set to false otherwise.
    let reservedForSecondFactor: Bool
    /// Set to true if this phone number is the default second factor. Set to false otherwise. A user must have exactly one default second factor, if multi-factor authentication (2FA) is enabled.
    let defaultSecondFactor: Bool
    /// An object holding information on the verification of this phone number.
    let verification: Verification
    /// An object containing information about any other identification that might be linked to this phone number.
    let linkedTo: JSON
    ///
    let backupCodes: [String]
}

extension PhoneNumber {
    
    struct CreateParams: Encodable {
        /// The value of the phone number, in E.164 format.
        let phoneNumber: String
    }
    
}
