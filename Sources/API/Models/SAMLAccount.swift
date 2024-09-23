//
//  SAMLAccount.swift
//
//
//  Created by Mike Pitre on 2/15/24.
//

import Foundation

public struct SAMLAccount: Codable, Equatable, Sendable, Hashable {
    public let object: String
    public let id: String
    public let provider: String
    public let active: Bool
    public let emailAddress: String?
    public let firstName: String?
    public let lastName: String?
    public let providerUserId: String?
    public let publicMetadata: JSON?
    public let verification: Verification?
}
