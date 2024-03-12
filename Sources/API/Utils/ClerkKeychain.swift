//
//  ClerkKeychain.swift
//
//
//  Created by Mike Pitre on 12/11/23.
//

import Foundation

enum ClerkKeychainKey {
    static let deviceToken = "deviceToken"
    static let client = "client"
    static let sessionsByUserId = "sessionsByUserId"
    static let sessionTokensByCacheKey = "sessionTokensByCacheKey"
    static let environment = "environment"
    static let publishableKey = "publishableKey"
}
