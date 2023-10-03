//
//  SessionWithActivities.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct SessionWithActivities: Codable {
    public let id: String
    public let status: SessionStatus
    public let lastActiveAt: Date
    public let abandonAt: Date
    public let expireAt: Date
    public let latestActivity: SessionActivity
}
