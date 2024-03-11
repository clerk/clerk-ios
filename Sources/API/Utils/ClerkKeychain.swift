//
//  ClerkKeychain.swift
//
//
//  Created by Mike Pitre on 12/11/23.
//

import Foundation
import KeychainAccess
import Factory

extension Keychain: @unchecked Sendable { }

extension Keychain {
    
    // clerk.{APP_NAME}
    static var clerk: Keychain {
        Container.shared.keychain()
    }
}

enum ClerkKeychainKey {
    static let deviceToken = "deviceToken"
    static let client = "client"
    static let sessionsByUserId = "sessionsByUserId"
    static let sessionTokensByCacheKey = "sessionTokensByCacheKey"
    static let environment = "environment"
    static let publishableKey = "publishableKey"
}
