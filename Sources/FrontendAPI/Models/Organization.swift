//
//  Organization.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct Organization: Codable {
    public let id: String
    public let name: String
    public let slug: String?
    public let imageUrl: String
    public let membersCount: Int
    public let pendingInvitationsCount: Int
    public let publicMetadata: JSON
    public let createdAt: Date
    public let updatedAt: Date
}
