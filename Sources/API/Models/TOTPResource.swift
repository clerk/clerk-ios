//
//  TOTPResource.swift
//
//
//  Created by Mike Pitre on 2/13/24.
//

import Foundation

public struct TOTPResource: Codable {
    public let object: String
    public let id: String
    public let secret: String
    public let uri: String
    public let verified: Bool
    public let backupCodes: [String]?
    public let createdAt: Date
    public let updatedAt: Date
}
