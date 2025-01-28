//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import Foundation
import Factory

extension Clerk {
    
     public struct Environment: Codable, Sendable {
        public var authConfig: AuthConfig?
        public var userSettings: UserSettings?
        public var displayConfig: DisplayConfig?
    }
    
}

extension Clerk.Environment {
    
    @discardableResult @MainActor
    public static func get() async throws -> Clerk.Environment {
        let request = ClerkFAPI.v1.environment.get
        let environment = try await Clerk.shared.apiClient.send(request).value
        Clerk.shared.environment = environment
        return environment
    }
    
}
