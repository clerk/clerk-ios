//
//  User.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

import Foundation

/**
 The User object holds all of the information for a single user of your application and provides a set of methods to manage their account. Each user has a unique authentication identifier which might be their email address, phone number, or a username.

 A user can be contacted at their primary email address or primary phone number. They can have more than one registered email address, but only one of them will be their primary email address. This goes for phone numbers as well; a user can have more than one, but only one phone number will be their primary. At the same time, a user can also have one or more external accounts by connecting to OAuth providers such as Google, Apple, Facebook, and many more.

 Finally, a User object holds profile data like the user's name, profile picture, and a set of metadata that can be used internally to store arbitrary information. The metadata are split into publicMetadata and privateMetadata. Both types are set from the Backend API, but public metadata can also be accessed from the Frontend API.
 */
public struct User: Decodable {
    /// A unique identifier for the user.
    let id: String
    let username: String?
    /// The user's first name.
    let firstName: String?
    /// The user's last name.
    let lastName: String?
    ///
    let gender: String?
    ///
    let birthday: String?
    /// Holds the users profile image or avatar.
    public let imageUrl: String
    /// A getter boolean to check if the user has uploaded an image or one was copied from OAuth. Returns false if Clerk is displaying an avatar for the user.
    let hasImage: Bool
    /// The unique identifier for the EmailAddress that the user has set as primary.
    let primaryEmailAddressId: String?
    /// The unique identifier for the PhoneNumber that the user has set as primary.
    let primaryPhoneNumberId: String?
    /// The unique identifier for the Web3Wallet that the user signed up with.
    let primaryWeb3WalletId: String?
    /// A boolean indicating whether the user has a password on their account.
    let passwordEnabled: Bool
    /// A boolean indicating whether the user has enabled two-factor authentication.
    let twoFactorEnabled: Bool
    /// A boolean indicating whether the user has enabled TOTP by generating a TOTP secret and verifying it via an authenticator app.
    let totpEnabled: Bool
    /// A boolean indicating whether the user has enabled Backup codes.
    let backupCodeEnabled: Bool
    /// An array of all the EmailAddress objects associated with the user. Includes the primary.
    let emailAddresses: [EmailAddress]
    /// An array of all the PhoneNumber objects associated with the user. Includes the primary.
    let phoneNumbers: [PhoneNumber]
    /// An array of all the Web3Wallet objects associated with the user. Includes the primary.
    let web3Wallets: [String]
    /// An array of all the ExternalAccount objects associated with the user via OAuth. Note: This includes both verified & unverified external accounts.
//    let externalAccounts: [ExternalAccount]
    /// An experimental list of saml accounts associated with the user.
    let samlAccounts: [String]
    /// Metadata that can be read from the Frontend API and Backend API and can be set only from the Backend API .
    let publicMetadata: JSON?
    /**
     Metadata that can be read and set from the Frontend API. One common use case for this attribute is to implement custom fields that will be attached to the User object.
     Please note that there is also an unsafeMetadata attribute in the SignUp object. The value of that field will be automatically copied to the user's unsafe metadata once the sign up is complete.
     */
    let unsafeMetadata: JSON?
    ///
    let externalId: String?
    /// Date when the user last signed in. May be empty if the user has never signed in.
    let lastSignInAt: Date?
    ///
    let banned: Bool
    ///
    let locked: Bool
    /// Date when the user was first created.
    let createdAt: Int
    /// Date of the last time the user was updated.
    let updatedAt: Date?
    /// A boolean indicating whether the user is able to delete their own account or not.
    let deleteSelfEnabled: Bool
    /// A boolean indicating whether the organization creation is enabled for the user or not.
    let createOrganizationEnabled: Bool
}
