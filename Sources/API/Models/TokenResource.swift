//
//  TokenResource.swift
//
//
//  Created by Mike Pitre on 12/13/23.
//

import Foundation

public struct TokenResource: Codable, Equatable {
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
