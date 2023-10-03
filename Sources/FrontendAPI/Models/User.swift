//
//  User.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct User: Codable {
    public let id: String
    public let firstName: String?
    public let lastName: String?
    public let fullName: String?
    public let username: String?
    public let imageUrl: String
    public let primaryEmailAddress: String?
    public let primaryEmailAddressId: String?
    public let emailAddresses: [EmailAddress]
    public let hasVerifiedEmailAddress: Bool
    public let primaryPhoneNumber: PhoneNumber?
    public let primaryPhoneNumberId: String?
    public let phoneNumbers: [PhoneNumber]
    public let hasVerifiedPhoneNumber: Bool
    public let primaryWeb3Wallet: Web3Wallet?
    public let web3Wallets: [Web3Wallet]
    public let externalAccounts: [ExternalAccount]
//    public let samlAccounts: [SamlAccount]
    public let organizationMemberships: [OrganizationMembership]
    public let passwordEnabled: Bool
    public let totpEnabled: Bool
    public let twoFactorEnabled: Bool
    public let backupCodeEnabled: Bool
    public let createOrganizationEnabled: Bool
    public let deleteSelfEnabled: Bool
    public let publicMetadata: JSON?
    public let privateMetadata: JSON?
    public let unsafeMetadata: JSON?
    public let createdAt: Date
    public let updatedAt: Date
}
