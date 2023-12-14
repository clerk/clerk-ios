//
//  ClerkKeychain.swift
//
//
//  Created by Mike Pitre on 12/11/23.
//

import Foundation
import KeychainAccess

extension Clerk {
    
    static let keychain = Keychain(service: "com.clerk")
    
    enum KeychainKey {
        static let deviceToken = "deviceToken"
        static let client = "client"
        static let sessionsByUserId = "sessionsByUserId"
        static let sessionTokensByCacheKey = "sessionTokensByCacheKey"
        static let environment = "environment"
    }
}
