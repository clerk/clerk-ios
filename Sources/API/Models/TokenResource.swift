//
//  TokenResource.swift
//
//
//  Created by Mike Pitre on 12/13/23.
//

import Foundation

/// Represents information about a token.
public struct TokenResource: Codable, Equatable {
    /// The requested token.
    public let jwt: String
}

extension TokenResource {
    var decodedJWT: DecodedJWT? {
        do {
            return try DecodedJWT(jwt: jwt)
        } catch {
            dump(error)
            return nil
        }
    }
}
