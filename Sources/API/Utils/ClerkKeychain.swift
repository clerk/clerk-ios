//
//  ClerkKeychain.swift
//
//
//  Created by Mike Pitre on 12/11/23.
//

import Foundation
import KeychainAccess

extension Keychain {
    
    // clerk.{APP_NAME}
    static var clerk: Keychain {
        var service = "clerk"
        if let appName = Bundle.main.appName { service += ".\(appName)" }
        return Keychain(service: service)
    }
}

enum ClerkKeychainKey {
    static let deviceToken = "deviceToken"
    static let client = "client"
    static let sessionsByUserId = "sessionsByUserId"
    static let sessionTokensByCacheKey = "sessionTokensByCacheKey"
    static let environment = "environment"
}
