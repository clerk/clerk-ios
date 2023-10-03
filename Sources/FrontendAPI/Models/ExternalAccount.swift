//
//  ExternalAccount.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct ExternalAccount: Codable {
    public let id: String
    public let identificationId: String
    public let provider: String
    public let publicMetadata: JSON
    public let providerUserId: String
    public let emailAddress: String
    public let approviedScopes: [String]
    public let firstName: String
    public let lastName: String
    public let avatarUrl: String
    public let username: String?
    public let label: String?
    public let verification: Verification
}
