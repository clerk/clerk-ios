//
//  Verification.swift
//  
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct Verification: Codable {
    public let attempts: Int?
    public let error: ClerkAPIError?
    public let expireAt: Date?
    public let externalVeriticationRedirectURL: String?
    public let nonce: String?
    public let status: String?
    public let strategy: String?
}
