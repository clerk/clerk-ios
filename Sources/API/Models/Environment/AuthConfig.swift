//
//  AuthConfig.swift
//  Clerk
//
//  Created by Mike Pitre on 8/2/24.
//

import Foundation

extension Clerk.Environment {
    
    public struct AuthConfig: Codable, Sendable {
        public let singleSessionMode: Bool
    }
    
}
