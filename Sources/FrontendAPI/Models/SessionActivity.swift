//
//  SessionActivity.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct SessionActivity: Codable {
    public let id: String
    public let browserName: String?
    public let browserVersion: String?
    public let deviceType: String?
    public let ipAddress: String?
    public let city: String?
    public let country: String?
    public let isMobile: Bool?
}
