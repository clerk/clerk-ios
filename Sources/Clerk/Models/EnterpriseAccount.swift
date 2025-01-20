//
//  EnterpriseAccount.swift
//  Clerk
//
//  Created by Mike Pitre on 1/10/25.
//

import Foundation

public struct EnterpriseAccount: Codable, Hashable, Equatable, Sendable {
    public let id: String
    public let object: String
    public let `protocol`: String
    public let provider: String
    public let active: Bool
    public let emailAddress: String
    public let firstName: String?
    public let lastName: String?
    public let providerUserId: String?
    public let publicMetadata: JSON
    public let verification: Verification?
    public let enterpriseConnection: EnterpriseConnection

    public struct EnterpriseConnection: Codable, Hashable, Equatable, Sendable {
        public let id: String
        public let `protocol`: String
        public let provider: String
        public let name: String
        public let logoPublicUrl: String
        public let domain: String
        public let active: Bool
        public let syncUserAttributes: Bool
        public let disableAdditionalIdentifications: Bool
        public let createdAt: Date
        public let updatedAt: Date
        public let allowSubdomains: Bool
        public let allowIdpInitiated: Bool
    }
}
