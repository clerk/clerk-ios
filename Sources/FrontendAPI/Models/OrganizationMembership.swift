//
//  OrganizationMembership.swift
//  
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct OrganizationMembership: Codable {
    public let id: String
    public let publicMetadata: JSON
    public let role: String
    public let publicUserData: PublicUserData
    public let organization: Organization
    public let createdAt: Date
    public let udpatedAt: Date
}
