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
        static let environment = "environment"
    }
    
    #if DEBUG
    public static func deleteRefreshToken() {
        try? Clerk.keychain.remove(Clerk.KeychainKey.deviceToken)
    }
    
    public static func deleteClient() {
        try? Clerk.keychain.remove(Clerk.KeychainKey.client)
    }
    
    public static func deleteSessions() {
        try? Clerk.keychain.remove(Clerk.KeychainKey.sessionsByUserId)
    }
    
    public static func deleteEnvironment() {
        try? Clerk.keychain.remove(Clerk.KeychainKey.environment)
    }
    
    public static func clearKeychain() {
        deleteRefreshToken()
        deleteClient()
        deleteSessions()
        deleteEnvironment()
    }
    #endif
}
