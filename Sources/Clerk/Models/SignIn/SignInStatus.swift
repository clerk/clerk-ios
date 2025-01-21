//
//  SignInStatus.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//


/// Represents the current status of the sign-in process.
///
/// The `SignInStatus` enum defines the possible states of a sign-in flow. Each state indicates a specific requirement or completion level in the sign-in process.
public enum SignInStatus: String, Codable, Sendable, Equatable {
    
    /// The user is signed in.
    case complete
    
    /// The user's identifier (e.g., email address, phone number, username) hasn't been provided.
    case needsIdentifier = "needs_identifier"
    
    /// A first-factor verification strategy is missing.
    ///
    /// This could include:
    /// - `email_link`
    /// - `email_code`
    /// - `phone_code`
    /// - `web3_metamask_signature`
    /// - `web3_coinbase_wallet_signature`
    /// - `oauth_provider`
    case needsFirstFactor = "needs_first_factor"
    
    /// A second-factor verification strategy is missing.
    ///
    /// This could include:
    /// - `phone_code`
    /// - `totp`
    case needsSecondFactor = "needs_second_factor"
    
    /// The user needs to set a new password.
    case needsNewPassword = "needs_new_password"
    
    /// The sign-in returned an unknown status value.
    case unknown
    
    /// Initializes a `SignInStatus` from a decoder.
    ///
    /// This initializer attempts to decode a `SignInStatus` from the raw value. If the value is not recognized, it defaults to `.unknown`.
    ///
    /// - Parameter decoder: The decoder to use for decoding the raw value.
    /// - Throws: An error if the decoding process fails.
    public init(from decoder: Decoder) throws {
        self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
    }
}

