//
//  ClerkAPIError.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct ClerkAPIError: Error, LocalizedError, Codable {
    var message: String?
    var longMessage: String?
    var code: String?
    var meta: Meta?
    
    public struct Meta: Codable {
        let paramName: String
    }
    
    public var errorDescription: String? { message }
}
