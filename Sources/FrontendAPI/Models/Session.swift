//
//  Session.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct Session: Codable {
    public let id: String
    public let user: User
    public let publicUserData: PublicUserData
    public let status: SessionStatus
    public let lastActiveAt: Date
    public let abandonAt: Date
    public let expireAt: Date
    public let updatedAt: Date
    public let createdAt: Date
//    public let lastActiveToken: TokenResource?
    public let lastActiveOrganizationId: String?
//    public let actor: ActJWTClaim?
}
