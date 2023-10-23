//
//  ExternalAccount.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import Foundation

/**
 The ExternalAccount object is a model around an identification obtained by an external provider (e.g. an OAuth provider such as Google).

 External account must be verified, so that you can make sure they can be assigned to their rightful owners. The ExternalAccount object holds all necessary state around the verification process.
 */
public struct ExternalAccount: Decodable {
    /// A unique identifier for this external account.
    let id: String
    
    /// The provider name e.g. google
    let provider: String
    
    /// The identification with which this external account is associated.
    let identificationId: String
    
    /// The unique ID of the user in the provider.
    let providerUserId: String
    
    /// The scopes that the user has granted access to.
    let approvedScopes: String
    
    /// The provided email address of the user.
    let emailAddress: String
    
    /// The provided first name of the user.
    let firstName: String
    
    /// The provided last name of the user.
    let lastName: String
    
    /// The provided avatar URL of the user.
    let avatarUrl: String
    
    ///
    let imageUrl: String
    
    /// The provided username of the user.
    let username: String?
    
    /// Metadata provided about the user from the provider.
    let publicMetadata: JSON
    
    /// A descriptive label to differentiate multiple external accounts of the same user for the same provider.
    let label: String?
    
    /// An object holding information on the verification of this external account.
    let verification: Verification
}
