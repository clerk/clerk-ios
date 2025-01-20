//
//  SignInFactor.swift
//
//
//  Created by Mike Pitre on 2/9/24.
//

import Foundation

/// Each factor contains information about the verification strategy that can be used.
public struct SignInFactor: Codable, Equatable, Hashable, Sendable {
    
    public init(
        strategy: String,
        emailAddressId: String? = nil,
        phoneNumberId: String? = nil,
        safeIdentifier: String? = nil,
        primary: Bool? = nil,
        `default`: Bool? = nil
    ) {
        self.strategy = strategy
        self.emailAddressId = emailAddressId
        self.phoneNumberId = phoneNumberId
        self.safeIdentifier = safeIdentifier
        self.primary = primary
        self.`default` = `default`
    }
    
    /// The strategy value depends on the object's identifier value. Each authentication identifier supports different verification strategies.
    public let strategy: String
        
    /// Unique identifier for the user's email address that will receive an email message with the one-time authentication code. This parameter will work only when the email_code strategy is specified.
    public let emailAddressId: String?
    
    /// Unique identifier for the user's phone number that will receive an SMS message with the one-time authentication code. This parameter will work only when the phone_code strategy is specified.
    public let phoneNumberId: String?
    
    public let safeIdentifier: String?
    
    public let primary: Bool?
    
    public let `default`: Bool?
}
