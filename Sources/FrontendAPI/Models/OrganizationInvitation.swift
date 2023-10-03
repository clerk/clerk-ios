//
//  OrganizationInvitation.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct OrganizationInvitation: Codable {
    public let id: String
    public let emailAddress: String
    public let organizationId: String
    public let publicMetadata: JSON
    public let role: String
    public let status: String
    public let createdAt: Date
    public let updatedAt: Date
}
