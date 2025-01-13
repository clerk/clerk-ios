//
//  EnterpriseAccount.swift
//  Clerk
//
//  Created by Mike Pitre on 1/10/25.
//

import Foundation

public struct EnterpriseAccount: Codable, Hashable, Equatable, Sendable {
    let id: String
    let object: String
    let `protocol`: String
    let provider: String
    let active: Bool
    let emailAddress: String
    let firstName: String?
    let lastName: String?
    let providerUserId: String?
    let publicMetadata: JSON
    let verification: Verification?
    let enterpriseConnection: EnterpriseConnection

    struct EnterpriseConnection: Codable, Hashable, Equatable, Sendable {
        let id: String
        let `protocol`: String
        let provider: String
        let name: String
        let logoPublicUrl: String
        let domain: String
        let active: Bool
        let syncUserAttributes: Bool
        let disableAdditionalIdentifications: Bool
        let createdAt: Date
        let updatedAt: Date
        let allowSubdomains: Bool
        let allowIdpInitiated: Bool
    }
}
